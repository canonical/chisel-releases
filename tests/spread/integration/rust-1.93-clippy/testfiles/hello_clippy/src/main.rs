fn main() {
    let v = vec![1, 2, 3];
    // This triggers clippy::len_zero: use is_empty() instead of len() == 0
    if v.len() == 0 {
        println!("empty");
    } else {
        println!("not empty");
    }
}
