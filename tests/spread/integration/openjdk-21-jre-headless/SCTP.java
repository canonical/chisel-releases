import java.io.*;
import java.net.*;

import com.sun.nio.sctp.*;

public class SCTP {

    static class Server implements Runnable {
        public static final int SERVER_ADDRESS = 9999;

        SctpServerChannel ssc;
        public Server() throws IOException {
            ssc = SctpServerChannel.open();
        }
        public void run() {
            try {
                InetSocketAddress addr = new InetSocketAddress(SERVER_ADDRESS);
                ssc.bind(addr);
                SctpChannel channel = ssc.accept();
                channel.shutdown();
                channel.close();
            }
            catch (IOException e) {
                throw new RuntimeException(e.getMessage());
            }
        }
    }

    public static void main(String[] args) throws Throwable {
        Server s = new Server();
        new Thread(s).start();
        int retries = 10;
        for (int i = 0; i < retries; ++i) {
            try {
                InetSocketAddress dest = new InetSocketAddress("::1", Server.SERVER_ADDRESS);
                SctpChannel sc = SctpChannel.open(dest, 0, 0);
                sc.close();
                System.out.println("Test success");
                System.exit(0);
            } catch (ConnectException e) {
                Thread.sleep(500);
            }
        }
        throw new RuntimeException("Failed to connect to sctp server.");
    }
}
