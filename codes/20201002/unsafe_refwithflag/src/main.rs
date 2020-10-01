mod ref_with_flag {
    use std::marker::PhantomData;
    use std::mem::align_of;

    pub struct RefWithFlag<'a, T: 'a> {
        ptr_and_bit: usize,
        behaves_like: PhantomData<&'a T>,
    }
    impl<'a, T: 'a> RefWithFlag<'a, T> {
        pub fn new(ptr: &'a T, flag: bool) -> RefWithFlag<T> {
            assert!(align_of::<T>() % 2 == 0);
            RefWithFlag {
                ptr_and_bit: ptr as *const T as usize | flag as usize,
                behaves_like: PhantomData,
            }
        }

        pub fn get_ref(&self) -> &'a T {
            unsafe {
                let ptr = (self.ptr_and_bit & !1) as *const T;
                &*ptr
            }
        }

        pub fn get_flag(&self) -> bool {
            (self.ptr_and_bit & 1) != 0
        }
    }
}

#[test]
fn refflag_with_usecase() {
    use ref_with_flag::RefWithFlag;

    let vec = vec![10, 20, 30];
    let flagged = RefWithFlag::new(&vec, true);

    assert_eq!(flagged.get_ref()[1], 20);
    assert_eq!(flagged.get_flag(), true);
}

fn main() {
    let slice: &[i32] = &[1, 3, 8, 27, 81, 36];
    println!("{:?}", std::mem::size_of_val(slice));
    println!("{:?}", std::mem::size_of::<&[i32]>());
    println!("{:?}", std::mem::align_of::<&[i32]>());
    println!("{:?}", std::mem::align_of::<i32>());
    println!("{:?}", std::mem::size_of::<i32>());
    println!("{:?}", std::mem::size_of::<&i32>());
    println!("{:?}", std::mem::size_of::<usize>());
    println!("{:?}", std::mem::size_of::<isize>());

    assert_eq!(std::mem::size_of::<i64>(), 8);
    assert_eq!(std::mem::align_of::<(i32, i32)>(), 4);
}
