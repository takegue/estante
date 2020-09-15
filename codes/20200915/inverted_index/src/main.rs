extern crate argparse;

use argparse::{ArgumentParser, Collect, StoreTrue};
use std::fs::File;
use std::io;
use std::io::prelude::*;
use std::path::PathBuf;
use std::sync::mpsc::{channel, Receiver};
use std::thread::{spawn, JoinHandle};

fn start_file_reader_thread(
    documents: Vec<PathBuf>,
) -> (Receiver<String>, JoinHandle<io::Result<()>>) {
    let (sender, reciver) = channel();
    let handle = spawn(move || {
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

fn run_in_parrallel(filenames: Vec<String>) -> io::Result<()> {
    // let output_dir = PathBuf::from(".");
    let documents = expand_filename_argumentrs(filenames)?;
    let _ = start_file_reader_thread(documents);

    Ok(())
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
