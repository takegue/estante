use std::collections::HashMap;

fn main() {
    let mut dict: HashMap<&str, &str> = HashMap::new();
    {
        let hoge = "fuga";
        dict.insert("test", hoge);
    }

    println!("{:?}", dict["test"]);
    let _debug_dump_dict = || {
        for (k, v) in &dict {
            println!("{:?} - {:?}", k, v);
        }
    };
}
