fn main() {
    let v: Vec<i32> = vec![1, 2, 3];
    // Reads past the end of the allocation. Rust compiles and runs this
    // happily; Miri is expected to reject it.
    let x = unsafe { *v.as_ptr().add(5) };
    println!("{}", x);
}
