fn main() {
    #[cfg(target_os = "macos")]
    keyagent::run();

    #[cfg(not(target_os = "macos"))]
    {
        eprintln!("keyagent only runs on macOS");
        std::process::exit(1);
    }
}
