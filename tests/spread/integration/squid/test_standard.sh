#!/usr/bin/env bash
# spellchecker: ignore rootfs
source "$(dirname "$0")/helpers.sh"

# perl-base_modules and libmysqlclient24_libs are only 
# needed for log_db_daemon tests in a mysql db
rootfs="$(install-slices \
    squid_standard \
    perl-base_modules \
    libmysqlclient24_libs
)"

# Create a test user (username: testuser, password: testpass)
mkdir -p "$rootfs/etc/squid/auth"
printf "testuser:$(openssl passwd -apr1 testpass)\n" > "$rootfs/etc/squid/auth/passwd"

# Configured standard NCSA auth managed by helper-mux
echo "auth_param basic program /usr/lib/squid/helper-mux /usr/lib/squid/basic_ncsa_auth /etc/squid/auth/passwd" >> "$rootfs/etc/squid/squid.conf"
echo "auth_param basic children 20 startup=5 idle=1" >> "$rootfs/etc/squid/squid.conf"
echo "auth_param basic concurrency 10" >> "$rootfs/etc/squid/squid.conf"

# Setup mysql for testing
apt install -y mysql-server
apt download libdbd-mysql-perl && dpkg -x libdbd-mysql-perl_*.deb "$rootfs/" && rm libdbd-mysql-perl_*.deb

mysqld --initialize-insecure --user=mysql
mysqld_safe --user=mysql --mysql-native-password=ON &
trap "pkill mysqld; wait" EXIT

mysql -e "CREATE DATABASE IF NOT EXISTS squid_log;"
mysql -e "CREATE USER IF NOT EXISTS 'squid'@'127.0.0.1' IDENTIFIED WITH mysql_native_password BY 'your_password';"
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
echo "access_log daemon:/127.0.0.1/squid_log/access_log/squid/your_password squid_db" >> "$rootfs/etc/squid/squid.conf"
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

# Verify the request is logged in the database
mysql squid_log -e "SELECT http_status_code FROM access_log WHERE http_url = 'ubuntu.com:443';" | grep -qF "200"
