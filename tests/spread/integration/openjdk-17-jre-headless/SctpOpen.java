import com.sun.nio.sctp.SctpChannel;

public class SctpOpen {
    public static void main(String[] args) throws Exception {
        try (SctpChannel channel = SctpChannel.open()) {
            System.out.println("sctp channel open");
        }
    }
}
