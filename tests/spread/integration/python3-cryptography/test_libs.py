import datetime
import os

import cryptography
from cryptography import x509
from cryptography.fernet import Fernet
from cryptography.hazmat.bindings._rust import openssl
from cryptography.hazmat.primitives import hashes, hmac, serialization
from cryptography.hazmat.primitives.asymmetric import ec, ed25519, padding, rsa
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.x509.oid import NameOID


def check_native():
    # The Rust extension links libssl, so loading it proves the native side.
    print(cryptography.__version__, openssl.openssl_version_text())


def check_symmetric():
    f = Fernet(Fernet.generate_key())
    assert f.decrypt(f.encrypt(b"chisel")) == b"chisel"

    aead, nonce = AESGCM(AESGCM.generate_key(bit_length=256)), os.urandom(12)
    assert aead.decrypt(nonce, aead.encrypt(nonce, b"chisel", b"ad"), b"ad") == b"chisel"

    h = hashes.Hash(hashes.SHA256())
    h.update(b"chisel")
    assert h.finalize().hex() == "4437f8f0e4476fec3cf0ae3c120609dda3efe2fd6d601ec75d8f02ec0aa4d185"

    m = hmac.HMAC(b"key", hashes.SHA256())
    m.update(b"chisel")
    m.copy().verify(m.finalize())


def check_signatures():
    ed = ed25519.Ed25519PrivateKey.generate()
    ed.public_key().verify(ed.sign(b"chisel"), b"chisel")

    ecdsa = ec.ECDSA(hashes.SHA256())
    p256 = ec.generate_private_key(ec.SECP256R1())
    p256.public_key().verify(p256.sign(b"chisel", ecdsa), b"chisel", ecdsa)

    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    sig = key.sign(b"chisel", padding.PKCS1v15(), hashes.SHA256())
    key.public_key().verify(sig, b"chisel", padding.PKCS1v15(), hashes.SHA256())
    return key


def check_certificate(key):
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "chisel")])
    now = datetime.datetime.now(datetime.timezone.utc)
    cert = (
        x509.CertificateBuilder()
        .subject_name(name)
        .issuer_name(name)
        .public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now)
        .not_valid_after(now + datetime.timedelta(days=1))
        .sign(key, hashes.SHA256())
    )
    back = x509.load_pem_x509_certificate(cert.public_bytes(serialization.Encoding.PEM))
    assert back.subject.get_attributes_for_oid(NameOID.COMMON_NAME)[0].value == "chisel"


check_native()
check_symmetric()
check_certificate(check_signatures())
