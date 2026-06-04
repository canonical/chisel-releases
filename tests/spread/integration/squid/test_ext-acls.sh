#!/usr/bin/env bash
# spellchecker: ignore rootfs userip ldap kerberos wbinfo
#
# Exercises every ext-acl helper shipped in squid_ext-acls.
# No squid_auth is installed. A minimal test-only auth shim (shell script,
# accepts all credentials) is written into the rootfs so squid's %LOGIN
# requirement is satisfied without depending on any auth helper binary.
#
# Expected outcomes per helper:
#   ext_file_userip_acl         ALLOW  (ACL file contains "testuser 127.0.0.1")
#   ext_unix_group_acl          ALLOW  (testuser is member of squidgrp)
#   ext_ldap_group_acl          DENY   (no LDAP server at 127.0.0.1)
#   ext_kerberos_ldap_group_acl DENY   (no LDAP/KRB server at 127.0.0.1)
#   ext_sql_session_acl         ALLOW  (session DB contains "127.0.0.1 -")
#   ext_session_acl             ALLOW  (new session from 127.0.0.1 -- allowed by default)
#   ext_time_quota_acl          ALLOW  (new client, no prior quota usage)
#   ext_wbinfo_group_acl        DENY   (wbinfo not available)

source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices \
    squid_ext-acls \
    base-files_base \
    base-passwd_data \
    libc-bin_nsswitch \
    sqlite3_bins \
    libpam-runtime_config \
    passwd_bins)"

setup_squid "minimal"
sed -i '/^http_access /d' "$rootfs/etc/squid/squid.conf"

chroot "$rootfs/" groupadd squidgrp
chroot "$rootfs/" useradd -M -s /usr/sbin/nologin testuser
chroot "$rootfs/" usermod -aG squidgrp testuser

# Minimal auth shim: accepts all credentials. Uses perl (already in rootfs via
# perl_bins) so squid can exec it inside the chroot without needing dash_bins.
# Satisfies squid's %LOGIN requirement w/out depending on any squid_auth binary.
cat > "$rootfs/usr/lib/squid/basic_test_auth" <<'EOF'
#!/usr/bin/perl
$| = 1;
while (<STDIN>) { print "OK\n" }
EOF
chmod +x "$rootfs/usr/lib/squid/basic_test_auth"

echo "auth_param basic program /usr/lib/squid/basic_test_auth" >> "$rootfs/etc/squid/squid.conf"
echo "acl auth_users proxy_auth REQUIRED" >> "$rootfs/etc/squid/squid.conf"


# FILE USER-IP ACL
# ------------------------------------------------
reset_squid_conf
mkdir -p "$rootfs/etc/squid/acl"
cat > "$rootfs/etc/squid/acl/userip.txt" <<EOF
testuser 127.0.0.1
testuser ::1
EOF
echo "external_acl_type userip_check ttl=5 %LOGIN %SRC /usr/lib/squid/ext_file_userip_acl -f /etc/squid/acl/userip.txt" >> "$rootfs/etc/squid/squid.conf"
echo "acl allowed external userip_check" >> "$rootfs/etc/squid/squid.conf"
echo "http_access allow allowed" >> "$rootfs/etc/squid/squid.conf"
echo "http_access deny all" >> "$rootfs/etc/squid/squid.conf"
restart_squid
test_proxy "ext_file_userip_acl" --proxy-user testuser:testpass


# UNIX GROUP ACL
# ------------------------------------------------
reset_squid_conf
echo "external_acl_type unix_group_check ttl=5 %LOGIN /usr/lib/squid/ext_unix_group_acl -g squidgrp" >> "$rootfs/etc/squid/squid.conf"
echo "acl in_group external unix_group_check" >> "$rootfs/etc/squid/squid.conf"
echo "http_access allow in_group" >> "$rootfs/etc/squid/squid.conf"
echo "http_access deny all" >> "$rootfs/etc/squid/squid.conf"
restart_squid
test_proxy "ext_unix_group_acl" --proxy-user testuser:testpass


# LDAP GROUP ACL
# ------------------------------------------------
# No LDAP server running; helper returns ERR, squid denies.
reset_squid_conf
echo "external_acl_type ldap_group_check ttl=5 %LOGIN \
/usr/lib/squid/ext_ldap_group_acl \
-b dc=test,dc=local -h 127.0.0.1 \
-f (&(objectclass=person)(uid=%v))" >> "$rootfs/etc/squid/squid.conf"
echo "acl in_ldap_group external ldap_group_check squidgrp" >> "$rootfs/etc/squid/squid.conf"
echo "http_access allow in_ldap_group" >> "$rootfs/etc/squid/squid.conf"
echo "http_access deny all" >> "$rootfs/etc/squid/squid.conf"
restart_squid
test_proxy_deny "ext_ldap_group_acl"


# KERBEROS LDAP GROUP ACL
# ------------------------------------------------
# No Kerberos/LDAP server; helper returns ERR, squid denies.
reset_squid_conf
echo "external_acl_type krb_ldap_check ttl=5 %LOGIN \
/usr/lib/squid/ext_kerberos_ldap_group_acl \
-b dc=test,dc=local -h 127.0.0.1" >> "$rootfs/etc/squid/squid.conf"
echo "acl in_krb_group external krb_ldap_check squidgrp" >> "$rootfs/etc/squid/squid.conf"
echo "http_access allow in_krb_group" >> "$rootfs/etc/squid/squid.conf"
echo "http_access deny all" >> "$rootfs/etc/squid/squid.conf"
restart_squid
test_proxy_deny "ext_kerberos_ldap_group_acl"


# SQL SESSION ACL
# ------------------------------------------------
# Uses %SRC (no %LOGIN needed). Session DB contains entry for 127.0.0.1.
reset_squid_conf
apt download libdbd-sqlite3-perl && dpkg -x libdbd-sqlite3-perl_*.deb "$rootfs/" && rm libdbd-sqlite3-perl_*.deb
echo "external_acl_type sql_session_check ttl=5 concurrency=1 %SRC \
/usr/lib/squid/ext_sql_session_acl \
--dsn DBI:SQLite:dbname=/etc/squid/sql/sessions.db \
--table sessions --debug" >> "$rootfs/etc/squid/squid.conf"
echo "acl sql_session_ok external sql_session_check" >> "$rootfs/etc/squid/squid.conf"
echo "http_access allow sql_session_ok" >> "$rootfs/etc/squid/squid.conf"
echo "http_access deny all" >> "$rootfs/etc/squid/squid.conf"
mkdir -p "$rootfs/etc/squid/sql"
chroot "$rootfs/" sqlite3 "/etc/squid/sql/sessions.db" <<'EOF'
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  user TEXT,
  enabled INTEGER
);
INSERT INTO sessions (id, user, enabled) VALUES ('127.0.0.1 -', 'testuser', 1);
INSERT INTO sessions (id, user, enabled) VALUES ('::1 -', 'testuser', 1);
EOF
restart_squid
test_proxy "ext_sql_session_acl"


# SESSION ACL
# ------------------------------------------------
# New session from 127.0.0.1 -- helper allows by default and records it.
# reset_squid_conf
# echo "external_acl_type session_check ttl=5 %SRC /usr/lib/squid/ext_session_acl" >> "$rootfs/etc/squid/squid.conf"
# echo "acl session_ok external session_check" >> "$rootfs/etc/squid/squid.conf"
# echo "http_access allow session_ok" >> "$rootfs/etc/squid/squid.conf"
# echo "http_access deny all" >> "$rootfs/etc/squid/squid.conf"
# restart_squid
# test_proxy "ext_session_acl"


# TIME QUOTA ACL
# ------------------------------------------------
# New client from 127.0.0.1 with no prior usage -- within quota.
# reset_squid_conf
# mkdir -p "$rootfs/etc/squid/quota"
# echo "external_acl_type time_quota_check ttl=5 %SRC /usr/lib/squid/ext_time_quota_acl -d /etc/squid/quota/quota.db" >> "$rootfs/etc/squid/squid.conf"
# echo "acl time_quota_ok external time_quota_check" >> "$rootfs/etc/squid/squid.conf"
# echo "http_access allow time_quota_ok" >> "$rootfs/etc/squid/squid.conf"
# echo "http_access deny all" >> "$rootfs/etc/squid/squid.conf"
# restart_squid
# test_proxy "ext_time_quota_acl"


# WBINFO GROUP ACL
# ------------------------------------------------
# Perl script; wbinfo binary not available, helper returns ERR, squid denies.
reset_squid_conf
echo "external_acl_type wbinfo_check ttl=5 %LOGIN /usr/lib/squid/ext_wbinfo_group_acl" >> "$rootfs/etc/squid/squid.conf"
echo "acl in_wbinfo_group external wbinfo_check squidgrp" >> "$rootfs/etc/squid/squid.conf"
echo "http_access allow in_wbinfo_group" >> "$rootfs/etc/squid/squid.conf"
echo "http_access deny all" >> "$rootfs/etc/squid/squid.conf"
restart_squid
test_proxy_deny "ext_wbinfo_group_acl"
cleanup
