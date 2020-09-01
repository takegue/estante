mod btree;

use btree::*;

struct I32Range {
    start: i32,
    end: i32,
}

impl Iterator for I32Range {
    type Item = i32;
    fn next(&mut self) -> Option<i32> {
        if self.start >= self.end {
            return None;
        }
        let result = Some(self.start);
        self.start += 1;
        result
    }
}

#[test]
fn test_simple_iterator() {
    let mut pi = 0.0;
    let mut numerator = 1.0;
    for k in (I32Range { start: 0, end: 14 }) {
        pi += numerator / (2 * k + 1) as f64;
        numerator /= -3.0;
    }
    pi *= f64::sqrt(12.0);

    assert_eq!(pi as f32, std::f32::consts::PI)
}

fn make_node<T>(left: BinaryTree<T>, element: T, right: BinaryTree<T>) -> BinaryTree<T> {
    BinaryTree::NonEmpty(Box::new(TreeNode {
        left,
        element,
        right,
    }))
}

fn main() {
    let subtree_l = make_node(BinaryTree::Empty, "mecha", BinaryTree::Empty);
    let subtree_rl = make_node(BinaryTree::Empty, "droid", BinaryTree::Empty);
    let subtree_r = make_node(subtree_rl, "robot", BinaryTree::Empty);
    let tree = make_node(subtree_l, "Jaeger", subtree_r);

    let mut v = Vec::new();
    for kind in &tree {
        v.push(*kind);
    }
    assert_eq!(v, ["mecha", "Jaeger", "droid", "robot"]);
    assert_eq!(
        tree.iter()
            .map(|name| format!("mega-{}", name))
            .collect::<Vec<_>>(),
        vec!["mega-mecha", "mega-Jaeger", "mega-droid", "mega-robot"]
    );
}
