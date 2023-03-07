mod index;
mod tmp_dir;
mod writer;

use argparse::{ArgumentParser, Collect, StoreTrue};

use index::InMemoryIndex;
use std::fs::File;
use std::io;
use std::io::prelude::*;
use std::path::{Path, PathBuf};
use std::sync::mpsc::{channel, Receiver};
use std::thread;
use writer::write_index_to_tmp_file;

fn start_file_reader_thread(
    documents: Vec<PathBuf>,
) -> (Receiver<String>, thread::JoinHandle<io::Result<()>>) {
    let (sender, reciver) = channel();
    let handle = thread::spawn(move || {
        for filename in documents {
            let mut f = File::open(filename)?;
            let mut text = String::new();
            f.read_to_string(&mut text)?;
            if sender.send(text).is_err() {
                break;
            }
        }
        Ok(())
    });

    (reciver, handle)
}

fn start_index_writer_thread(
    big_indexes: Receiver<InMemoryIndex>,
    output_dir: &Path,
) -> (Receiver<PathBuf>, thread::JoinHandle<io::Result<()>>) {
    let (sender, receiver) = channel();
    let mut tdir = tmp_dir::TmpDir::new(output_dir);
    let handle = thread::spawn(move || {
        for index in big_indexes {
            let file = write_index_to_tmp_file(index, &mut tdir)?;
            if sender.send(file).is_err() {
                break;
            }
        }
        Ok(())
    });

    (receiver, handle)
}

fn merge_index_files(files: Receiver<PathBuf>, output_dir: &Path) -> io::Result<()> {
    Ok(())
}

fn start_in_memory_merge_thread(
    file_indexes: Receiver<InMemoryIndex>,
) -> (Receiver<InMemoryIndex>, thread::JoinHandle<()>) {
    let (sender, receiver) = channel();
    let handle = thread::spawn(move || {
        let mut bigone = InMemoryIndex::new();
        for child in file_indexes {
            bigone.merge(child);
            if bigone.is_large() {
                if sender.send(bigone).is_err() {
                    return;
                }
                bigone = InMemoryIndex::new();
            }
        }
    });
    (receiver, handle)
}

fn start_file_index_thread(
    texts: Receiver<String>,
) -> (Receiver<InMemoryIndex>, thread::JoinHandle<()>) {
    let (sender, receiver) = channel();
    let handle = thread::spawn(move || {
        for (doc_id, text) in texts.into_iter().enumerate() {
            let idx = InMemoryIndex::from_single_document(doc_id, text);
            if sender.send(idx).is_err() {
                break;
            }
        }
    });

    (receiver, handle)
}

fn run_in_parrallel(filenames: Vec<String>) -> io::Result<()> {
    let output_dir = PathBuf::from(".");
    let documents = expand_filename_argumentrs(filenames)?;

    let (texts, h1) = start_file_reader_thread(documents);
    let (pints, h2) = start_file_index_thread(texts);
    let (gallons, h3) = start_in_memory_merge_thread(pints);
    let (files, h4) = start_index_writer_thread(gallons, &output_dir);
    let result = merge_index_files(files, &output_dir);

    let r1 = h1.join().unwrap();
    h2.join().unwrap();
    h3.join().unwrap();
    let r4 = h4.join().unwrap();

    r1?;
    r4?;
    result
}

fn expand_filename_argumentrs(args: Vec<String>) -> io::Result<Vec<PathBuf>> {
    let mut filenames = vec![];
    for arg in args {
        let path = PathBuf::from(arg);
        if path.metadata()?.is_dir() {
            for entry in path.read_dir()? {
                let entry = entry?;
                if entry.file_type()?.is_file() {
                    filenames.push(entry.path());
                } else {
                    unimplemented!();
                }
            }
        } else {
            filenames.push(path);
        }
    }
    Ok(filenames)
}

fn run(filenames: Vec<String>, single_threaded: bool) -> io::Result<()> {
    if single_threaded {
        unimplemented!();
    } else {
        run_in_parrallel(filenames)
    }
}

fn main() {
    let mut single_threaded = false;
    let mut filenames: Vec<String> = vec![];

    {
        let mut ap = ArgumentParser::new();
        ap.set_description("Make an inverted index for searching documents.");
        ap.refer(&mut single_threaded).add_option(
            &["-1", "--single-threaded"],
            StoreTrue,
            "Do all the work on a single thread.",
        );
        ap.refer(&mut filenames).add_argument(
            "filenames",
            Collect,
            "Names of files/directories to index. \
                           For directories, all .txt files immediately \
                           under the directory are indexed.",
        );
        ap.parse_args_or_exit();
    }

    match run(filenames, single_threaded) {
        Ok(()) => {}
        Err(err) => eprintln!("{}", err),
    }
}
