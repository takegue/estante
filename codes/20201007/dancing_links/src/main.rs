use std::fmt;
use std::ops;

#[derive(Default, Copy, Clone, PartialEq, Debug)]
struct Cell(usize);

impl<T> ops::Index<Cell> for Vec<T> {
    type Output = T;
    fn index(&self, index: Cell) -> &Self::Output {
        &self[index.0]
    }
}

impl<T> ops::IndexMut<Cell> for Vec<T> {
    fn index_mut(&mut self, index: Cell) -> &mut Self::Output {
        &mut self[index.0]
    }
}

// TODO: To remove duplication on next/prev method for Cursor, You should try to define `Link` as follows;
// type Link = [Cell; 2];

#[derive(Debug)]
struct Link {
    prev: Cell,
    next: Cell,
}

#[derive(Default, Debug)]
struct LinkedList {
    data: Vec<Link>,
}

impl ops::Index<Cell> for LinkedList {
    type Output = Link;
    fn index(&self, index: Cell) -> &Link {
        &self.data[index.0]
    }
}

impl ops::IndexMut<Cell> for LinkedList {
    fn index_mut(&mut self, index: Cell) -> &mut Link {
        &mut self.data[index.0]
    }
}

impl LinkedList {
    fn with_capacity(cap: usize) -> LinkedList {
        LinkedList {
            data: Vec::with_capacity(cap),
        }
    }

    fn alloc(&mut self) -> Cell {
        let cell = Cell(self.data.len());
        self.data.push(Link {
            prev: cell,
            next: cell,
        });
        cell
    }

    /// Inserts `b` into `a <-> c` to get `a <-> b <-> c`
    fn insert(&mut self, a: Cell, b: Cell) {
        let c = self[a].next;

        self[b].prev = a;
        self[b].next = c;

        self[a].next = b;
        self[c].prev = b;
    }

    /// Removes `b` from `a <-> b <-> c` to get `a <-> c`
    fn remove(&mut self, b: Cell) {
        let a = self[b].prev;
        let c = self[b].next;

        self[a].next = c;
        self[c].prev = a;
    }

    /// Restores previously removed `b` to get `a <-> b <-> c`
    fn restore(&mut self, b: Cell) {
        let a = self[b].prev;
        let c = self[b].next;

        self[a].next = b;
        self[c].prev = b;
    }
}

struct Cursor {
    head: Cell,
    curr: Cell,
}

impl LinkedList {
    fn cursor(&self, head: Cell) -> Cursor {
        Cursor { head, curr: head }
    }
}

impl Cursor {
    fn next(&mut self, list: &LinkedList) -> Option<Cell> {
        self.curr = list[self.curr].next;
        if self.curr == self.head {
            return None;
        }
        Some(self.curr)
    }

    fn prev(&mut self, list: &LinkedList) -> Option<Cell> {
        self.curr = list[self.curr].prev;
        if self.curr == self.head {
            return None;
        }
        Some(self.curr)
    }
}

struct Matrix {
    x: LinkedList,
    y: LinkedList,
    c: Vec<Cell>,
    r: Vec<Cell>,
    size: Vec<u32>,
}

const H: Cell = Cell(0);
impl Matrix {
    fn new(n_cols: usize) -> Matrix {
        let mut res = Matrix {
            size: Vec::with_capacity(n_cols + 1),
            c: Vec::with_capacity(n_cols + 1),
            r: Vec::with_capacity(0),
            x: LinkedList::with_capacity(n_cols + 1),
            y: LinkedList::with_capacity(n_cols + 1),
        };

        assert_eq!(res.alloc_column(), H);
        for _ in 0..n_cols {
            res.add_column();
        }
        res
    }
    fn add_column(&mut self) {
        let new_col = self.alloc_column();
        let last_column = self.x[H].prev;
        self.x.insert(last_column, new_col);
    }

    fn alloc_column(&mut self) -> Cell {
        let cell = self.alloc(H);
        self.c[cell] = cell;
        self.size.push(0);
        cell
    }

    fn alloc(&mut self, c: Cell) -> Cell {
        self.c.push(c);
        self.r.push({
            if self.r.len() > 0 {
                self.r[self.r.len() - 1]
            } else {
                Cell(0)
            }
        });
        let cell_x = self.x.alloc();
        let cell_y = self.y.alloc();
        assert_eq!(cell_y, cell_x);
        cell_x
    }
}

impl Matrix {
    fn add_row(&mut self, row: &[bool]) {
        assert_eq!(row.len(), self.size.len() - 1);
        let mut c = H;
        let mut prev = None;

        let rn = Cell(self.r[self.r.len() - 1].0 + 1);
        for (_, &is_filled) in row.iter().enumerate() {
            c = self.x[c].next;
            if is_filled {
                self.size[c] += 1;
                let new_cell = self.alloc(c);
                self.r[new_cell] = rn;
                let last_y = self.y[c].prev;
                self.y.insert(last_y, new_cell);
                if let Some(prev) = prev {
                    self.x.insert(prev, new_cell);
                }
                prev = Some(new_cell);
            }
        }
    }
}

impl fmt::Display for Matrix {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut map = vec![vec![0u8; self.size.len()]; self.size.len()];

        let mut r = self.x.cursor(H);
        while let Some(i) = r.next(&self.x) {
            let mut j = self.x.cursor(i);
            while let Some(j) = j.next(&self.y) {
                map[self.r[j]][self.c[i]] = 1;
            }
        }

        for i in 1..self.size.len() {
            for j in 1..self.size.len() {
                write!(f, "{:^3}", map[i][j])?;
            }
            writeln!(f)?;
        }

        Ok(())
    }
}

impl fmt::Debug for Matrix {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        writeln!(f)?;

        write!(f, "i: ")?;
        for i in 0..self.x.data.len() {
            write!(f, "{:^5}", i)?;
        }
        writeln!(f)?;

        writeln!(f, "---{}", vec!["-----"; self.x.data.len()].join(""))?;

        write!(f, "s: ")?;
        for s in &self.size {
            write!(f, "{:^5}", s)?;
        }
        writeln!(f)?;

        write!(f, "c: ")?;
        for &Cell(c) in &self.c {
            write!(f, "{:^5}", c)?;
        }
        writeln!(f)?;

        write!(f, "r: ")?;
        for &Cell(r) in &self.r {
            write!(f, "{:^5}", r)?;
        }
        writeln!(f)?;

        write!(f, "x: ")?;
        for link in &self.x.data {
            write!(f, " {:>1}|{:<1} ", link.prev.0, link.next.0)?
        }
        writeln!(f)?;

        write!(f, "y: ")?;
        for link in &self.y.data {
            write!(f, " {:>1}|{:<1} ", link.prev.0, link.next.0)?
        }
        writeln!(f)?;

        Ok(())
    }
}

impl Matrix {
    fn cover(&mut self, c: Cell) {
        self.x.remove(c);
        let mut i = self.y.cursor(c);
        while let Some(i) = i.next(&self.y) {
            let mut j = self.x.cursor(i);
            while let Some(j) = j.next(&self.x) {
                self.y.remove(j);
                self.size[self.c[j]] -= 1;
            }
        }
    }

    fn uncover(&mut self, c: Cell) {
        let mut i = self.y.cursor(c);
        while let Some(i) = i.prev(&self.y) {
            let mut j = self.x.cursor(i);
            while let Some(j) = j.prev(&self.x) {
                self.size[self.c[j]] += 1;
                self.y.restore(j);
            }
            self.x.restore(i);
        }
        self.x.restore(c);
    }
}

fn solve(mut m: Matrix) -> usize {
    let mut n_answers = 0;
    go(&mut m, &mut n_answers);
    n_answers
}

fn go(m: &mut Matrix, n_answers: &mut usize) {
    let c = {
        let mut i = m.x.cursor(H);
        let mut c = match i.next(&m.x) {
            Some(it) => it,
            None => {
                *n_answers += 1;
                return;
            }
        };
        while let Some(next_c) = i.next(&m.x) {
            if m.size[next_c] < m.size[c] {
                c = next_c;
            }
        }
        c
    };

    m.cover(c);
    let mut r = m.y.cursor(c);
    while let Some(r) = r.next(&m.y) {
        let mut j = m.x.cursor(r);
        while let Some(j) = j.next(&m.x) {
            m.cover(m.c[j]);
        }
        go(m, n_answers);
        let mut j = m.x.cursor(r);
        while let Some(j) = j.prev(&m.x) {
            m.uncover(m.c[j]);
        }
    }
    m.uncover(c);
}

#[test]
fn smoke() {
    let f = false;
    let t = true;

    let mut m = Matrix::new(7);
    m.add_row(&[f, f, t, f, t, t, f]);
    m.add_row(&[t, f, f, t, f, f, t]);
    m.add_row(&[f, t, t, f, f, t, f]);
    m.add_row(&[t, f, f, t, f, f, f]);
    m.add_row(&[f, t, f, f, f, f, t]);
    m.add_row(&[f, f, f, t, t, f, t]);

    eprintln!("{}", m);
    m.cover(Cell(1));
    eprintln!("{} ", m);
}

#[test]
fn sample_problem() {
    let f = false;
    let t = true;

    let mut m = Matrix::new(3);
    m.add_row(&[f, t, t]);
    m.add_row(&[f, t, t]);
    m.add_row(&[t, t, f]);

    // let solutions = dbg!(solve(m));
    // assert_eq!(solutions, 1);

    // let mut m = Matrix::new(7);
    // m.add_row(&[f, t, f, t, t, f, f]);
    // m.add_row(&[f, f, t, f, f, t, t]);
    // m.add_row(&[t, t, f, f, t, f, f]);
    // m.add_row(&[f, f, t, f, f, f, t]);
    // m.add_row(&[t, f, f, f, f, t, f]);
    // m.add_row(&[f, f, t, t, f, t, f]);

    let solutions = dbg!(solve(m));
    assert_eq!(solutions, 1);
    panic!();
}

#[test]
fn exhaustive_test() {
    'matrix: for bits in 0..=0b1111_1111_1111_1111 {
        let mut rows = [0u32; 4];
        for (i, row) in rows.iter_mut().enumerate() {
            *row = (bits >> (i * 4)) & 0b1111;
            if *row == 0 {
                continue 'matrix;
            }
        }

        let brute_force = {
            let mut n_solutions = 0;
            for mask in 0..=0b1111 {
                let mut or = 0;
                let mut n_ones = 0;
                for (i, &row) in rows.iter().enumerate() {
                    if mask & (1 << i) != 0 {
                        or |= row;
                        n_ones += row.count_ones()
                    }
                }
                if or == 0b1111 && n_ones == 4 {
                    n_solutions += 1;
                }
            }
            n_solutions
        };

        let dlx = {
            let mut m = Matrix::new(4);
            for row_bits in rows.iter() {
                let mut row = [false; 4];
                for i in 0..4 {
                    row[i] = row_bits & (1 << i) != 0;
                }
                m.add_row(&row);
            }
            solve(m)
        };
        assert_eq!(brute_force, dlx)
    }
}

pub fn main() {
    println!("{:?}", vec!["----"; 4]);
}
