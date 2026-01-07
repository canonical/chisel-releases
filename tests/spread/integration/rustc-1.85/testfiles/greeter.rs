#[no_mangle]
pub extern "C" fn greet(who: *const u8) -> *const u8 {
    #[cfg(target_arch = "aarch64")]
    let c_str = unsafe { std::ffi::CStr::from_ptr(who) };
    #[cfg(not(target_arch = "aarch64"))]
    let c_str = unsafe { std::ffi::CStr::from_ptr(who as *const i8) };
    
    let name = c_str.to_str().unwrap_or("stranger");
    let greeting = format!("Hello to {} from Rust static library!", name);
    let c_greeting = std::ffi::CString::new(greeting).unwrap();
    
    #[cfg(target_arch = "aarch64")]
    return c_greeting.into_raw();
    #[cfg(not(target_arch = "aarch64"))]
    return c_greeting.into_raw() as *const u8;
}
