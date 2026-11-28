import java.security.MessageDigest;
import java.security.Provider;
import java.security.Security;

public class NssProvider {
    public static void main(String[] args) throws Exception {
        Provider nss = Security.getProvider("SunPKCS11").configure(args[0]);
        MessageDigest.getInstance("SHA-256", nss).digest("hello".getBytes());
        System.out.println("provider: " + nss.getName());
    }
}
