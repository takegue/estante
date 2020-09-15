extern crate argparse;

use argparse::{ArgumentParser, Collect, StoreTrue};

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

    println!("{:?} {:?}", single_threaded, filenames);
}
