import java.net.Proxy;
import java.net.ProxySelector;
import java.net.URI;
import java.util.List;

public class ProxyTest {
    public static void main(String[] args) throws Exception {
        // with java.net.useSystemProxies=true the lookup dlopens libgio, which
        // awt-v2 leaves out, so it has to fall back to a direct connection
        List<Proxy> proxies = ProxySelector.getDefault().select(new URI("http://example.com/"));
        if (!proxies.equals(List.of(Proxy.NO_PROXY))) {
            throw new AssertionError(proxies);
        }
        System.out.println(proxies);
    }
}
