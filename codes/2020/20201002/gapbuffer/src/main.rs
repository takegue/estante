mod gap;

use crate::gap::GapBuffer;

fn main() {
    let mut buf = GapBuffer::new();
    buf.insert_iter("Lord of thr Rings".chars());
    buf.set_position(12);
    buf.insert_iter("Onion".chars());
}
