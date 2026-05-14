#!/usr/bin/env bash
# spellchecker: ignore rootfs
source "$(dirname "$0")/helpers.sh"

# sqlite3_bins is only required for the SQL session ACL test
# passwd_bins is required to create users for the ACL tests
# libpam-runtime_config is required for the chpasswd to work
rootfs="$(install-slices \
    squid_ext-acls \
    base-files_base \
    base-passwd_data \
    libc-bin_nsswitch \
    sqlite3_bins \
    libpam-runtime_config \
    passwd_bins)"

setup_squid

# Remove pre-existing http_access rules
sed -i '/^http_access /d' "$rootfs/etc/squid/squid.conf"

# create user + group
chroot "$rootfs/" groupadd squidgrp
chroot "$rootfs/" useradd -M -s /usr/sbin/nologin testuser
chroot "$rootfs/" usermod -aG squidgrp testuser
echo "testuser:testpass" | chroot "$rootfs/" chpasswd

# Add basic authentication (required for %LOGIN usage in ACLs)
echo "auth_param basic program /usr/lib/squid/basic_getpwnam_auth" >> "$rootfs/etc/squid/squid.conf"
echo "acl auth_users proxy_auth REQUIRED" >> "$rootfs/etc/squid/squid.conf"

# FILE USER-IP ACL
# ------------------------------------------------
reset_squid_conf

# Configure ACL
echo "external_acl_type userip_check ttl=5 %LOGIN %SRC /usr/lib/squid/ext_file_userip_acl -f /etc/squid/acl/userip.txt" >> "$rootfs/etc/squid/squid.conf"
echo "acl allowed_users external userip_check" >> "$rootfs/etc/squid/squid.conf"
echo "http_access allow allowed_users" >> "$rootfs/etc/squid/squid.conf"
echo "http_access deny all" >> "$rootfs/etc/squid/squid.conf"

# Create User IP ACL file
mkdir -p "$rootfs/etc/squid/acl"
cat > "$rootfs/etc/squid/acl/userip.txt" <<EOF
testuser 127.0.0.1
testuser ::1
EOF

restart_squid
test_proxy "ext_file_userip_acl" --proxy-user testuser:testpass


# UNIX GROUP ACL
# ------------------------------------------------
reset_squid_conf

# Configure ACL
echo "external_acl_type unix_group_check ttl=5 %LOGIN /usr/lib/squid/ext_unix_group_acl -g squidgrp" >> "$rootfs/etc/squid/squid.conf"
echo "acl allowed_users external unix_group_check" >> "$rootfs/etc/squid/squid.conf"
echo "http_access allow allowed_users" >> "$rootfs/etc/squid/squid.conf"
echo "http_access deny all" >> "$rootfs/etc/squid/squid.conf"

restart_squid
test_proxy "ext_unix_group_acl" --proxy-user testuser:testpass


# SQL SESSION ACL
# ------------------------------------------------
reset_squid_conf

# Manually add the sqlite perl module (Only for tests)
apt download libdbd-sqlite3-perl && dpkg -x libdbd-sqlite3-perl_*.deb "$rootfs/" && rm libdbd-sqlite3-perl_*.deb

# Configure ACL
echo "external_acl_type sql_session_check ttl=5 concurrency=1 %SRC \
/usr/lib/squid/ext_sql_session_acl \
--dsn DBI:SQLite:dbname=/etc/squid/sql/sessions.db \
--table sessions --debug" >> "$rootfs/etc/squid/squid.conf"

echo "acl sql_session_ok external sql_session_check" >> "$rootfs/etc/squid/squid.conf"
echo "http_access allow sql_session_ok" >> "$rootfs/etc/squid/squid.conf"
echo "http_access deny all" >> "$rootfs/etc/squid/squid.conf"

# Create sessions database
mkdir -p "$rootfs/etc/squid/sql"
chroot "$rootfs/" sqlite3 "/etc/squid/sql/sessions.db" <<'EOF'
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  user TEXT,
  enabled INTEGER
);
INSERT INTO sessions (id, user, enabled)
VALUES ('127.0.0.1 -', 'testuser', 1);
INSERT INTO sessions (id, user, enabled)
VALUES ('::1 -', 'testuser', 1);
EOF

restart_squid
test_proxy "ext_sql_session_acl" --proxy-user testuser:testpass
