use std::fmt;
use std::ops;

#[derive(Default, Copy, Clone, PartialEq, Debug)]
struct Cell(usize);

struct Link {
    prev: Cell,
    next: Cell,
}
// TODO: To remove duplication on next/prev method for Cursor, You should try to define `Link` as follows;
// type Link = [Cell; 2];

#[derive(Default)]
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
    size: Vec<u32>,
}

const H: Cell = Cell(0);
impl Matrix {
    fn new(n_cols: usize) -> Matrix {
        let mut res = Matrix {
            size: Vec::with_capacity(n_cols + 1),
            c: Vec::with_capacity(n_cols + 1),
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
        self.x.insert(self.x[H].prev, new_col);
    }

    fn alloc_column(&mut self) -> Cell {
        let cell = self.alloc(H);
        self.c[cell] = cell;
        self.size.push(0);
        cell
    }

    fn alloc(&mut self, c: Cell) -> Cell {
        self.c.push(c);
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
        for &is_filled in row {
            c = self.x[c].next;
            if is_filled {
                self.size[c] += 1;
                let new_cell = self.alloc(c);
                self.y.insert(self.y[c].prev, new_cell);
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
        write!(f, "s: ")?;
        for s in &self.size {
            write!(f, "{:^5}", s)?;
        }
        writeln!(f)?;

        write!(f, "c: ")?;
        for &Cell(c) in &self.c {
            write!(f, "{:^5}", c.saturating_sub(1))?;
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

        write!(f, "i: ")?;
        for i in 0..self.x.data.len() {
            write!(f, "{:^5}", i)?;
        }
        writeln!(f)?;

        Ok(())
    }
}

pub fn main() {
    let mut m = Matrix::new(3);
    println!("{}", m);
    m.add_row(&[true, false, true]);
    println!("{}", m);
}
