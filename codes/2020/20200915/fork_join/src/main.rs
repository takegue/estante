use std::io;
use std::sync::Arc;
use std::thread::spawn;

fn load(filename: &str) -> io::Result<String> {
    println!("{}", filename.to_string());
    Ok("Hoge".to_string())
}

fn process(text: String) -> io::Result<String> {
    println!("{}", text);
    Ok(text)
}

fn save(filename: &str, result: String) -> io::Result<()> {
    println!("{} {}", filename, result);
    Ok(())
}

fn process_files_in_parallel(filenames: Vec<String>) -> io::Result<()> {
    const NTHREADS: usize = 8;
    let worklists = filenames.chunks(filenames.len() / NTHREADS);
    let mut thread_handles = vec![];
    for worklist in worklists {
        let worklist = worklist.to_vec();
        thread_handles.push(spawn(move || process_files(worklist)));
    }
    for handle in thread_handles {
        handle.join().unwrap()?;
    }
    Ok(())
}

fn process_files(filenames: Vec<String>) -> io::Result<()> {
    for document in filenames {
        let text = load(&document)?;
        let result = process(text);
        save(&document, result.unwrap())?;
    }
    Ok(())
}

fn main() {
    let _ = process_files(
        (vec!["a", "b", "c"])
            .into_iter()
            .map(|s| s.to_string())
            .collect(),
    );
    println!("Hello, world!");
}
