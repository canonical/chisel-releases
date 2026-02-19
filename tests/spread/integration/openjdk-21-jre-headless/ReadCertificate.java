import java.security.cert.*;
import java.io.*;

public class ReadCertificate {

    static final String PEM = """
-----BEGIN CERTIFICATE-----
MIIDazCCAlOgAwIBAgIULvuqN3MiptnZSYS9y1qJAZYKFA4wDQYJKoZIhvcNAQEL
BQAwRTELMAkGA1UEBhMCQVUxEzARBgNVBAgMClNvbWUtU3RhdGUxITAfBgNVBAoM
GEludGVybmV0IFdpZGdpdHMgUHR5IEx0ZDAeFw0yNDA4MTUwMjQzNDhaFw0yNTA4
MTUwMjQzNDhaMEUxCzAJBgNVBAYTAkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEw
HwYDVQQKDBhJbnRlcm5ldCBXaWRnaXRzIFB0eSBMdGQwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQDm3990peBuPYaz0UEEc75Q7i79P4RzrD84MxhDpoPs
MSdnmO3rTkIG84Wp72+8T7TGjGjBhX++8UmZLrXy2AfcejZi3JcddMWH4V5XEnAj
hTBe1HLkiotayZst/cxuTP6KmuahjsROAqriCv/A4BBA8KjYx1e4E9k9+81FreZy
PJ8p3m7R8qZ/DtjuW1aMQ3oDRKA/iqQhLHVpJy/iYiyjwTdJm6/lA3ywGCr6ZMWm
9tWUT+4TvhyRM67Y0gcCtH51cwxPqUFGEKAkLWIu2fS6DaoXtHylxgGeKKPes3JX
uSn9QezEEqvrgLFQRqIUS8tNZFEhoJQ7dmxMP/XKAD51AgMBAAGjUzBRMB0GA1Ud
DgQWBBSb70j+xaI3eTxp4H7MDm1MLVRGNTAfBgNVHSMEGDAWgBSb70j+xaI3eTxp
4H7MDm1MLVRGNTAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQAp
0GIjKtwvD7BkQy+cf3dsdwYodxoIYl4E8UvHfBSPQQfFNh+chHPmrNYRuFM3Q6sT
ogNhHKLecQMK4tNUDa/vVRGnqmZVWjxqLnyH/qFKtakqPB6h6x4h50huzA+twhNm
SDjg3QqqpOuUzrs77JqYkxSjqd0QgmwmgxOdbcF0SY+ebQhAd0UXY7wIs6ByDEHO
kElgJmnGKhOpf1SFpQh2qpKGq/MvcdHWN4oKri440wCf+czkrOTyGVc275oTbRnM
Z76Ro4JDuomyWeR9iQ5pP5ug4ciflLa7hlYcH0xJbF3b2M3BlnUYKMqih/TjqKdr
NBs121h64SPY0gh7kIvF
-----END CERTIFICATE-----
            """;
    
    public static void main(String[] args) throws Throwable {
        java.security.cert.Certificate cert = CertificateFactory.getInstance("X509").generateCertificate(new ByteArrayInputStream(PEM.getBytes()));
        if (cert == null)
            throw new RuntimeException("It should be possible to decode a certificate");
    }
}
