import java.security.cert.*;
import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;

public class ReadCertificate {

    public static void main(String[] args) throws Throwable {
        byte[] pem = Files.readAllBytes(Path.of("certificate.pem"));
        java.security.cert.Certificate cert = CertificateFactory.getInstance("X509").generateCertificate(new ByteArrayInputStream(pem));
        if (cert == null)
            throw new RuntimeException("It should be possible to decode a certificate");
    }
}
