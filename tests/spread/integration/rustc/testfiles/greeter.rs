#[no_mangle]
pub extern "C" fn greet(who: *const u8) -> *const u8 {
    let c_str = unsafe { std::ffi::CStr::from_ptr(who) };
    let name = c_str.to_str().unwrap_or("stranger");
    let greeting = format!("Hello to {} from Rust static library!", name);
    let c_greeting = std::ffi::CString::new(greeting).unwrap();
    c_greeting.into_raw()
}
