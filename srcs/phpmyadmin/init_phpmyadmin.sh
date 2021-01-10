#!/bin/sh

# Allow to run openrc service on a system not booted by openrc
mkdir -p /run/openrc
touch /run/openrc/softlevel
# Change runlevel to allow phpmyadmin start up
openrc 2> /dev/null
# Phpmyadmin
while true; do
	wget -P /tmp -T 15 -c \
		"https://files.phpmyadmin.net/phpMyAdmin/5.0.4/phpMyAdmin-5.0.4-english.tar.gz" \
		&& break
done
tar -xf /tmp/phpMyAdmin-5.0.4-english.tar.gz -C /tmp
rm /tmp/phpMyAdmin-5.0.4-english.tar.gz
mv /tmp/phpMyAdmin-5.0.4-english /var/www/phpmyadmin
mysql -h mariadb-service.default.svc.cluster.local \
	-u ${USER_SVC} --password=${PASSWORD} \
	< /var/www/phpmyadmin/sql/create_tables.sql
mysql -h mariadb-service.default.svc.cluster.local \
	-u ${USER_SVC} --password=${PASSWORD} \
	< /var/www/phpmyadmin/sql/upgrade_tables_4_7_0+.sql
mkdir /var/www/phpmyadmin/tmp
mv /tmp/config.inc.php /var/www/phpmyadmin/
chmod 777 /var/www/phpmyadmin/tmp
mkdir /var/lib/php7/sessions
chmod 777 -R /var/lib/php7/sessions
sed -i 's/;session\.save_path = "\/tmp"/session.save_path = "\/var\/lib\/php7\/sessions"/' \
	/etc/php7/php.ini
BLOWFISH_SECRET=$(openssl rand -hex 32)
BLOWFISH_SECRET=$(echo ${BLOWFISH_SECRET:0:32})
sed -i "s/\['blowfish_secret'\] = ''/\['blowfish_secret'\] = '${BLOWFISH_SECRET}'/" \
	/var/www/phpmyadmin/config.inc.php
sed -i "s/\['user'\] = ''/\['user'\] = '${USER_SVC}'/" \
	/var/www/phpmyadmin/config.inc.php
sed -i "s/\['password'\] = ''/\['password'\] = '${PASSWORD}'/" \
	/var/www/phpmyadmin/config.inc.php
# Nginx
openssl req -nodes -x509 -newkey rsa:2048 -keyout /etc/ssl/private/key.pem -out /etc/ssl/certs/cert.pem -days 182 -subj "/C=FR/ST=Paris/L=Paris/O=42/OU=42student/CN=PhpMyAdmin.com"
mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak
# Start
service php-fpm7 start 2> /dev/null
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
sed -i 's/hostname = ""/hostname = "phpmyadmin"/' /etc/telegraf/telegraf.conf
telegraf &

sleep infinity
