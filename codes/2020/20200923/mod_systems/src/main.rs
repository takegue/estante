mod greeting;
mod life;

use greeting::hello;

fn main() {
    hello();
    life::fuga::sleep();
}
