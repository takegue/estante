fn main() {
    assert_eq!(
        "élan".char_indices().collect::<Vec<_>>(),
        vec![(0, 'é'), (2, 'l'), (3, 'a'), (4, 'n'),]
    );

    // assert_eq!("elan".char_indices().collect::<Vec<_>>(),
    // vec![195, 169, b'1', b'a', '']
    //     )

    println!("Hello, world!");
}
