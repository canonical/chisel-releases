#!/usr/bin/env bash
# spellchecker: ignore rootfs
source "$(dirname "$0")/helpers.sh"

# perl-base_modules and libdbd-mysql-perl_modules are only
# needed for log_db_daemon tests in a mysql db
rootfs="$(install-slices \
    squid_standard \
    perl-base_modules \
    libdbd-mysql-perl_modules
)"

# Create a test user (username: testuser, password: testpass)
mkdir -p "$rootfs/etc/squid/auth"
printf "testuser:$(openssl passwd -apr1 testpass)\n" > "$rootfs/etc/squid/auth/passwd"

# Configured standard NCSA auth managed by helper-mux
echo "auth_param basic program /usr/lib/squid/helper-mux /usr/lib/squid/basic_ncsa_auth /etc/squid/auth/passwd" >> "$rootfs/etc/squid/squid.conf"
echo "auth_param basic children 20 startup=5 idle=1 concurrency=10" >> "$rootfs/etc/squid/squid.conf"

# Setup mysql for testing. The server is the one thing the host provides:
# log_db_daemon only talks to it over tcp, it is not part of the rootfs.
apt install -y mysql-server
trap "pkill mysqld; wait; cleanup" EXIT

# Enable mysql_native_password plugin
echo "[mysqld]" > /etc/mysql/mysql.conf.d/mysql.cnf
echo "mysql_native_password=ON" >> /etc/mysql/mysql.conf.d/mysql.cnf
service mysql restart

mysql -e "CREATE DATABASE IF NOT EXISTS squid_log;"
mysql -e "CREATE USER IF NOT EXISTS 'squid'@'127.0.0.1' IDENTIFIED WITH mysql_native_password BY 'test_password';"
mysql -e "GRANT ALL PRIVILEGES ON squid_log.* TO 'squid'@'127.0.0.1';"
mysql -e "FLUSH PRIVILEGES;"
mysql squid_log <<EOF
CREATE TABLE IF NOT EXISTS access_log (
    id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,
    time_since_epoch DECIMAL(15,3),
    time_response INTEGER,
    ip_client CHAR(15),
    ip_server CHAR(15),
    http_status_code VARCHAR(10),
    http_reply_size INTEGER,
    http_method VARCHAR(20),
    http_url TEXT,
    http_username VARCHAR(20),
    http_mime_type VARCHAR(50),
    squid_request_status VARCHAR(50),
    squid_hier_status VARCHAR(20)
);
EOF

# Configure log_db_daemon
echo "logformat squid_db %ts.%03tu %tr %>a %Ss/%03>Hs %<st %rm %ru %[un %Sh/%<a %mt" >> "$rootfs/etc/squid/squid.conf"
echo "access_log daemon:/127.0.0.1/squid_log/access_log/squid/test_password squid_db" >> "$rootfs/etc/squid/squid.conf"
echo "logfile_daemon /usr/lib/squid/log_db_daemon" >> "$rootfs/etc/squid/squid.conf"

# Startup squid
setup_squid
restart_squid

# Assertions
ps -aux | grep -qF "unlinkd"
ps -aux | grep -qF "pinger"
ps -aux | grep -qF "diskd"
ps -aux | grep -qF "log_db_daemon"
ps -aux | grep -qF "/usr/lib/squid/helper-mux /usr/lib/squid/basic_ncsa_auth /etc/squid/auth/passwd"

test_proxy "standard"

# Verify the request is logged in the database. log_db_daemon writes behind
# the request, so give it a moment.
query="SELECT http_status_code FROM access_log WHERE http_url = 'ubuntu.com:443';"
for i in $(seq 30); do
    mysql squid_log -Nse "$query" | grep -qF "200" && break
    sleep 1
done
echo "logged after ${i}s"
mysql squid_log -Nse "$query" | grep -qF "200"

cleanup
