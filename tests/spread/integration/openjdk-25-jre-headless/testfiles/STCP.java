import com.sun.nio.sctp.*;
import java.io.* ;
import java.nio.ByteBuffer;
import java.nio.CharBuffer;
import java.nio.charset.*;
import java.net.*;
import java.util.concurrent.CountDownLatch;

public class STCP {
    static int SERVER_PORT = 3456;
    static int STREAM_ID = 0;

    static CountDownLatch startSignal = new CountDownLatch(1);

    static class Server implements Runnable {
        public void run() {
            try {
                SctpServerChannel ssc = SctpServerChannel.open();
                InetSocketAddress serverAddr = new InetSocketAddress(SERVER_PORT);
                ssc.bind(serverAddr);
                CharsetEncoder encoder = Charset.defaultCharset().newEncoder();
                ByteBuffer buf = ByteBuffer.allocateDirect(60);
                startSignal.countDown();

                SctpChannel sc = ssc.accept();

                CharBuffer cb = CharBuffer.allocate(60);
                cb.put("Test message".toCharArray());
                cb.flip();
                buf.put(encoder.encode(cb));
                buf.flip();
                /* send the message on the US stream */
                MessageInfo messageInfo = MessageInfo.createOutgoing(null, STREAM_ID);
                sc.send(buf, messageInfo);

                buf.clear();

                sc.close();
            }
            catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    public static void main(String[] args) throws IOException, InterruptedException {
        try {
            Thread th = new Thread(new Server());
            th.start();
            startSignal.await();
            InetSocketAddress serverAddr = new InetSocketAddress("localhost",
                    SERVER_PORT);
            ByteBuffer buf = ByteBuffer.allocateDirect(60);

            SctpChannel sc = SctpChannel.open(serverAddr, 0, 0);
            MessageInfo messageInfo = sc.receive(buf, null, null);
            buf.flip();
            CharsetDecoder decoder = Charset.defaultCharset().newDecoder();
            CharBuffer cb = decoder.decode(buf);
            System.out.println("STREAM: "+messageInfo.streamNumber() + ": " + cb);
            sc.close();
        } catch (Throwable t) {
            t.printStackTrace();
            System.exit(-1);
        }
    }
}
