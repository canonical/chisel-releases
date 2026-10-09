use std::fs::{self, File};
use std::io::{Read, Write};
use std::sync::{Arc, Mutex};
use std::thread;
use std::collections::HashMap;
use std::time::{Duration, Instant};

// each test returns Result<(), String> where Err contains error message
type TestResult = Result<(), String>;
type TestFunc = fn() -> TestResult;

fn main() {
    println!("Running basic standard library checks...");

    // array of function pointers, and names for reporting
    let tests: [(TestFunc, &str); 7] = [
        (check_collections, "Collections"),
        (check_arithmetic, "Arithmetic"),
        (check_file_io, "File I/O"),
        (check_concurrency, "Concurrency"),
        (check_mem, "Memory"),
        (check_time, "Time"),
        (check_env, "Environment Variables and Args"),
    ];

    let mut overall_result: bool = true;
    for (i, (test, name)) in tests.iter().enumerate() {
        let result = test();
        match result {
            Ok(_) => println!("Test {} ({}) passed", i + 1, name),
            Err(e) => {
                println!("Test {} ({}) failed: {}", i + 1, name, e);
                overall_result = false;
            }
        }
    }

    if !overall_result {
        println!("Some tests failed.");
        std::process::exit(1);
    } else {
        println!("\nAll basic checks passed!");
    }
}

fn assert(condition: bool, message: &str) -> TestResult {
    if condition {
        Ok(())
    } else {
        Err(message.to_string())
    }
}

////////////////////////////////////////////////////////////////////////////////

fn check_collections() -> TestResult {
    // Test String and Vec
    let mut s = String::from("hello");
    s.push_str(" world");
    assert(s == "hello world", "String manipulation failed")?;
    
    let mut v = Vec::new();
    v.push(1);
    v.push(2);
    v.push(3);
    assert(v == vec![1, 2, 3], "Vector manipulation failed")?;

    // Test HashMap
    let mut map = HashMap::new();
    map.insert("key1", 10);
    map.insert("key2", 20);
    assert(map.get("key1") == Some(&10), "HashMap get failed")?;
    assert(map.len() == 2, "HashMap length incorrect")?;
    map.remove("key1");
    assert(!map.contains_key("key1"), "HashMap remove failed")?;

    Ok(())
}

fn check_arithmetic() -> TestResult {
    // Test integer operations
    assert(10 + 5 == 15, "Integer addition failed")?;
    assert(10 - 5 == 5, "Integer subtraction failed")?;
    assert(10 * 5 == 50, "Integer multiplication failed")?;
    assert(10 / 5 == 2, "Integer division failed")?;
    assert(10 % 3 == 1, "Integer modulus failed")?;

    // Test floating point operations and edge cases
    let a = 10.0;
    let b = 5.0;
    assert(a / b == 2.0, "Floating point division failed")?;

    // Test division by zero results in infinity
    let c = 1.0;
    let d = 0.0;
    assert(c / d == f64::INFINITY, "Division by zero did not yield infinity")?;
    Ok(())
}

fn check_file_io() -> TestResult {
    let filename = "test_file.txt";
    let test_data = "Hello from Rust file I/O!";

    // Write to a file
    let mut file = File::create(filename).map_err(|e| format!("File creation failed: {}", e))?;
    file.write_all(test_data.as_bytes()).map_err(|e| format!("File write failed: {}", e))?;

    // Read from the file
    let mut file = File::open(filename).map_err(|e| format!("File open failed: {}", e))?;
    let mut contents = String::new();
    file.read_to_string(&mut contents).map_err(|e| format!("File read failed: {}", e))?;
    assert(contents == test_data, "File contents do not match")?;

    // Clean up
    fs::remove_file(filename).map_err(|e| format!("File removal failed: {}", e))?;
    Ok(())
}

fn check_concurrency() -> TestResult {
    let counter = Arc::new(Mutex::new(0));
    let mut handles = vec![];

    for _ in 0..10 {
        let counter_clone = Arc::clone(&counter);
        let handle = thread::spawn(move || {
            let mut num = counter_clone.lock().unwrap();
            *num += 1;
        });
        handles.push(handle);
    }

    for handle in handles {
        handle.join().map_err(|e| format!("Thread join failed: {:?}", e))?;
    }

    assert(*counter.lock().unwrap() == 10, "Counter value incorrect")?;
    Ok(())
}


fn check_mem() -> TestResult {
    // Test size_of for fundamental types
    assert(std::mem::size_of::<i32>() == 4, "size_of::<i32>() failed")?;
    assert(std::mem::size_of::<f64>() == 8, "size_of::<f64>() failed")?;
    
    // Test alignment of types
    assert(std::mem::align_of::<i32>() == 4, "align_of::<i32>() failed")?;
    assert(std::mem::align_of::<f64>() == 8, "align_of::<f64>() failed")?;

    // Test a struct with different alignments
    // spellchecker: ignore repr
    #[repr(C)]
    struct AlignedStruct {
        a: i8,
        b: i32,
    }
    assert(std::mem::size_of::<AlignedStruct>() == 8, "size_of::<AlignedStruct>() failed")?;
    
    Ok(())
}

fn check_time() -> TestResult {
    // Test high-resolution timer
    let start = Instant::now();
    let duration = Duration::from_millis(50);
    thread::sleep(duration);
    let elapsed = start.elapsed();
    assert(elapsed >= duration, &format!("Sleep duration incorrect. Expected at least {:?}, got {:?}", duration, elapsed))?;
    
    // Test system time
    let system_now = std::time::SystemTime::now();
    let since_epoch = system_now.duration_since(std::time::UNIX_EPOCH)
                                .map_err(|e| format!("System time duration_since failed: {}", e))?;
    assert(since_epoch.as_secs() > 1700000000, "System time is likely incorrect or too far in the past")?;

    Ok(())
}

fn check_env() -> TestResult {
    let test_key = "RUST_TEST_VAR";
    let test_val = "rust_test_value";

    // Set and get an environment variable
    std::env::set_var(test_key, test_val);
    let var_val = std::env::var(test_key).map_err(|e| format!("Failed to get env var: {}", e))?;
    assert(var_val == test_val, "Failed to get correct environment variable value")?;
    
    // Test that args() returns at least one element (the program name)
    let args: Vec<String> = std::env::args().collect();
    assert(args.len() >= 1, "Command line arguments check failed")?;
    
    Ok(())
}
