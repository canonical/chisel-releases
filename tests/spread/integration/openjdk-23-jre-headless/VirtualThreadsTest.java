public class VirtualThreadsTest {
    public static void main(String[] args) throws Exception {
        // Create and start 1,000 virtual threads
        final int threadCount = 1_000;
        final long[] results = new long[threadCount];
        Thread[] threads = new Thread[threadCount];
        long startTime = System.currentTimeMillis();
        // Create virtual threads, each doing a simple calculation
        for (int i = 0; i < threadCount; i++) {
            final int id = i;
            // Using the virtual thread factory API
            threads[i] = Thread.ofVirtual().name("virtual-thread-" + i).start(() -> {
                results[id] = fibonacci(15 + (id % 10));
            });
        }
        // Wait for all threads to complete
        for (Thread thread : threads) {
            thread.join();
        }
        long endTime = System.currentTimeMillis();
    }
    private static long fibonacci(int n) {
        if (n <= 1) return n;
        return fibonacci(n-1) + fibonacci(n-2);
    }
}
