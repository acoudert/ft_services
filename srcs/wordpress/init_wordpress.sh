#!/bin/sh

# Allow to run openrc service on a system not booted by openrc
mkdir -p /run/openrc
touch /run/openrc/softlevel
# Change runlevel to allow wordpress start up
openrc 2> /dev/null
# Setup wordpress
# Following loop to avoid frozen wget
while true; do 
	wget -P /var/www -T 15 -c "http://wordpress.org/latest.tar.gz" && break
done
tar -xf /var/www/latest.tar.gz -C /var/www
rm /var/www/latest.tar.gz
sed -i "s/'DB_USER', ''/'DB_USER', '${ADMIN_DB}'/" \
	/tmp/wp-config.php
sed -i "s/'DB_PASSWORD', ''/'DB_PASSWORD', '${PASSWORD_DB}'/" \
	/tmp/wp-config.php
export CONFIG=$(curl https://api.wordpress.org/secret-key/1.1/salt/ 2> /dev/null)
awk -v var="$CONFIG" '{sub("KEYS_SALTS", var, $0)}1' /tmp/wp-config.php \
	| sed 's/KEYS_SALTS//g' > /var/www/wordpress/wp-config.php
rm /tmp/wp-config.php
chmod -R 755 /var/www/wordpress
unset CONFIG
# WordPress users setup
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod 755 wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp
# Admin
wp core install --allow-root --path=/var/www/wordpress --url="235:5050" \
	--title="WordPress" --admin_user="$USER_ADMIN" \
	--admin_password="$PASS_ADMIN" --admin_email="admin@WordPress.com"
# Editor
wp user create $USER_EDITOR editor@WordPress.com \
	--role="editor" --user_pass="$PASS_EDITOR" \
	--allow-root --path=/var/www/wordpress
# Author
wp user create $USER_AUTHOR author@WordPress.com \
	--role="author" --user_pass="$PASS_AUTHOR" \
	--allow-root --path=/var/www/wordpress
# Contributor
wp user create $USER_CONTRIBUTOR contributor@WordPress.com \
	--role="contributor" --user_pass="$PASS_CONTRIBUTOR" \
	--allow-root --path=/var/www/wordpress
# Subscriber
wp user create $USER_SUBSCRIBER subscriber@WordPress.com \
	--role="subscriber" --user_pass="$PASS_SUBSCRIBER" \
	--allow-root --path=/var/www/wordpress
# Setup nginx
openssl req -nodes -x509 -newkey rsa:2048 -keyout /etc/ssl/private/key.pem -out /etc/ssl/certs/cert.pem -days 182 -subj "/C=FR/ST=Paris/L=Paris/O=42/OU=42student/CN=WordPress.com"
mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak
# Startup
service php-fpm7 start 2> dev/null
service nginx start 2> /dev/null

# Telegraf sidecar
while true; do
	wget -P /tmp -T 15 -c \
		"https://dl.influxdata.com/telegraf/releases/telegraf-1.17.0_linux_amd64.tar.gz" \
	       	&& break
done
tar -xf /tmp/telegraf-1.17.0_linux_amd64.tar.gz -C /tmp && mv /tmp/telegraf-1.17.0 /tmp/telegraf
# For musl glibc (Go dependencies)
mkdir /lib64 && ln -s /lib/libc.musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2
cp /tmp/telegraf/etc/logrotate.d/telegraf /etc/logrotate.d/telegraf
cp -R /tmp/telegraf/etc/telegraf /etc
cp /tmp/telegraf/usr/bin/telegraf /usr/bin/telegraf
cp -R /tmp/telegraf/usr/lib/telegraf /usr/lib
cp -R /tmp/telegraf/var/log/telegraf /var/log
rm -r /tmp/telegraf
telegraf --input-filter cpu:mem:net:system:netstat:processes \
	--output-filter influxdb config > /etc/telegraf/telegraf.conf
sed -i 's/# urls = \["http:\/\/127.0.0.1:8086"\]/urls = \["http:\/\/influxdb-service.default.svc.cluster.local:8086"\]/' \
	/etc/telegraf/telegraf.conf
sed -i "s/# username = \"telegraf\"/username = \"${USER_METRICS}\"/" \
	/etc/telegraf/telegraf.conf
sed -i "s/# password = \"metricsmetricsmetricsmetrics\"/password = \"${PASS_METRICS}\"/" \
	/etc/telegraf/telegraf.conf
sed -i 's/hostname = ""/hostname = "wordpress"/' /etc/telegraf/telegraf.conf
telegraf &

# Following command to avoid container to be terminated as soon as end of start up
sleep infinity

