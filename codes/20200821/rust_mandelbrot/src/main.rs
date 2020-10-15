extern crate num;
use num::Complex;

use std::str::FromStr;

#[derive(Debug)]
struct S;

fn hoge() {
    let y = 23;
    let yref = Box::new(y);
}

fn fuga(val: Box<u64>) {}

/// Try to detemine if `c` is in the Mandelbrot set, using at most `limit` iterations to decide.
fn complex_square_add_loop(c: Complex<f64>, limit: u32) -> Option<u32> {
    let mut z = Complex { re: 0.0, im: 0.0 };

    for i in 0..limit {
        z = z * z + c;
        if z.norm_sqr() > 4.0 {
            return Some(i);
        }
    }

    let mut args = [1, 2, 3];
    None
}

fn main() {
    println!("Hello, world!");
    println!("Hello, world!");
    println!("Hello, world!");
    println!("Hello, world!");
    println!("Hello, world!");
}
