#!/usr/bin/env bash
# spellchecker: ignore rootfs
source "$(dirname "$0")/helpers.sh"

# sqlite3_bins is only required for the DB auth test
# libpam-modules_libs is only required for the PAM auth test (provide pam_unix.so)
# libpam-runtime_config is only required for the PAM auth test (for chpasswd to work)
# passwd_bins is required for the GETPWNAM and PAM auth test (user creation and chpasswd)
rootfs="$(install-slices \
    squid_auth \
    base-files_base \
    base-passwd_data \
    libc-bin_nsswitch \
    sqlite3_bins \
    libpam-modules_libs \
    libpam-runtime_config \
    passwd_bins)"

setup_squid

# Remove pre-existing http_access rules
sed -i '/^http_access /d' "${rootfs}/etc/squid/squid.conf"


# NCSA AUTH
# ------------------------------------------------
reset_squid_conf

# Configure authentication
echo "auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/auth/passwd" >> "${rootfs}/etc/squid/squid.conf"
echo "acl auth_users proxy_auth REQUIRED" >> "${rootfs}/etc/squid/squid.conf"
echo "http_access allow auth_users" >> "${rootfs}/etc/squid/squid.conf"

# Create a test user (username: testuser, password: testpass)
mkdir -p "${rootfs}/etc/squid/auth"
printf "testuser:$(openssl passwd -apr1 testpass)\n" > "${rootfs}/etc/squid/auth/passwd"

restart_squid
test_proxy "basic_ncsa_auth" --proxy-user testuser:testpass


# GETPWNAM AUTH
# ------------------------------------------------
reset_squid_conf

echo "auth_param basic program /usr/lib/squid/basic_getpwnam_auth" >> "${rootfs}/etc/squid/squid.conf"
echo "acl auth_users proxy_auth REQUIRED" >> "${rootfs}/etc/squid/squid.conf"
echo "http_access allow auth_users" >> "${rootfs}/etc/squid/squid.conf"

# Create system user inside chroot
chroot "${rootfs}/" useradd -m testuser
echo "testuser:testpass" | chroot "${rootfs}/" chpasswd

restart_squid
test_proxy "basic_getpwnam_auth" --proxy-user testuser:testpass


# DIGEST FILE AUTH
# ------------------------------------------------
reset_squid_conf

# Digest auth config
echo "auth_param digest program /usr/lib/squid/digest_file_auth -c /etc/squid/auth/digest" >> "${rootfs}/etc/squid/squid.conf"
echo "auth_param digest realm testrealm" >> "${rootfs}/etc/squid/squid.conf"

echo "acl auth_users proxy_auth REQUIRED" >> "${rootfs}/etc/squid/squid.conf"
echo "http_access allow auth_users" >> "${rootfs}/etc/squid/squid.conf"
echo "http_access deny all" >> "${rootfs}/etc/squid/squid.conf"

# Create digest password file manually
mkdir -p "${rootfs}/etc/squid/auth"
echo testuser:testrealm:ebff225e1ceb73e026fcc645af3e84f6 > "${rootfs}/etc/squid/auth/digest"

restart_squid

test_proxy "digest_file_auth" --proxy-digest --proxy-user testuser:testpass


# DB AUTH (basic_db_auth)
# ------------------------------------------------
reset_squid_conf

# Manually add the sqlite perl module (Only for tests)
apt download libdbd-sqlite3-perl && dpkg -x libdbd-sqlite3-perl_*.deb "${rootfs}/" && rm libdbd-sqlite3-perl_*.deb

# Requires squid built with DB auth helper + sqlite DB
echo 'auth_param basic program /usr/lib/squid/basic_db_auth \
--dsn "DBI:SQLite:dbname=/etc/squid/auth/users.db" \
--table users \
--usercol username \
--passwdcol password \
--plaintext \
--cond ""' >> "${rootfs}/etc/squid/squid.conf"

echo "acl auth_users proxy_auth REQUIRED" >> "${rootfs}/etc/squid/squid.conf"
echo "http_access allow auth_users" >> "${rootfs}/etc/squid/squid.conf"
echo "http_access deny all" >> "${rootfs}/etc/squid/squid.conf"

mkdir -p "${rootfs}/etc/squid/auth"

# Create sqlite DB (schema depends on squid build; this is the common format)
chroot "${rootfs}/" sqlite3 "/etc/squid/auth/users.db" <<'EOF'
    CREATE TABLE users (username TEXT, password TEXT);
    INSERT INTO users VALUES ('testuser', 'testpass');
EOF

restart_squid
test_proxy "basic_db_auth" --proxy-user testuser:testpass


# BASIC PAM AUTH (basic_pam_auth)
# ------------------------------------------------
reset_squid_conf

echo "auth_param basic program /usr/lib/squid/basic_pam_auth -n squid" >> "${rootfs}/etc/squid/squid.conf"
echo "acl auth_users proxy_auth REQUIRED" >> "${rootfs}/etc/squid/squid.conf"
echo "http_access allow auth_users" >> "${rootfs}/etc/squid/squid.conf"
echo "http_access deny all" >> "${rootfs}/etc/squid/squid.conf"

# PAM service file
mkdir -p "${rootfs}/etc/pam.d"
cat > "${rootfs}/etc/pam.d/squid" <<EOF
auth    required pam_unix.so debug
account required pam_unix.so debug
EOF

# User and passwd created above in GETPWNAM test
# chroot "${rootfs}/" useradd -m testuser
# echo "testuser:testpass" | chroot "${rootfs}/" chpasswd

restart_squid
test_proxy "basic_pam_auth" --proxy-user testuser:testpass


# BASIC SASL AUTH (basic_sasl_auth)
# ------------------------------------------------
reset_squid_conf

# Manually add saslpasswd2 binary to create the sasldb (only for tests)
apt install -y --no-install-recommends sasl2-bin

# Configure Squid to use basic_sasl_auth
echo "auth_param basic program /usr/lib/squid/basic_sasl_auth" >> "${rootfs}/etc/squid/squid.conf"
echo "auth_param basic realm testrealm" >> "${rootfs}/etc/squid/squid.conf"
echo "acl auth_users proxy_auth REQUIRED" >> "${rootfs}/etc/squid/squid.conf"
echo "http_access allow auth_users" >> "${rootfs}/etc/squid/squid.conf"
echo "http_access deny all" >> "${rootfs}/etc/squid/squid.conf"

# SASL config
mkdir -p "${rootfs}/etc/sasl2"
cat > "${rootfs}/etc/sasl2/basic_sasl_auth.conf" <<EOF
pwcheck_method: auxprop
auxprop_plugin: sasldb
mech_list: PLAIN LOGIN
EOF

# Create sasl user using saslpasswd2 and move the generated sasldb into the chroot
echo "testpass" | saslpasswd2 -p -c -u testrealm testuser
mv /etc/sasldb2 "${rootfs}/etc/sasldb2"
chown proxy:proxy "${rootfs}/etc/sasldb2"
chmod 640 "${rootfs}/etc/sasldb2"

restart_squid
test_proxy "basic_sasl_auth" --proxy-user testuser@testrealm:testpass
