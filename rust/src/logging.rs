pub fn init_logging() {
    // Keep this simple for MVP.
    // Native platforms can swap in platform loggers later.
    let _ = tracing_subscriber::fmt()
        .with_env_filter("pika_core=debug,info")
        .try_init();
}
