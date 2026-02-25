import java.io.Console;

public class ConsoleTest {
    public static void main(String[] args) {
        Console c = System.console();
        if (c == null) {
            throw new RuntimeException("Console is not available");
        }
        c.printf("console output %s\n", "success");
    }
}
