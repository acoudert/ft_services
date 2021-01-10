#!/bin/sh

# Allow to run openrc service on a system not booted by openrc
mkdir -p /run/openrc
touch /run/openrc/softlevel
# Change runlevel to allow mariadb start up
openrc 2> /dev/null
# Start mariadb service
./etc/init.d/mariadb setup
service mariadb start 2> /dev/null
# Setup mariadb
printf "\nn\nn\ny\ny\ny\ny\n" | mysql_secure_installation

# WordPress User gets WordPress database access
sed -i "s/CREATE DATABASE.*/CREATE DATABASE WordPress;/" /tmp/mariadb.sql
sed -i "s/USER ''/USER '${USER_WP}'/" /tmp/mariadb.sql
sed -i "s/BY ''/BY '${PASSWORD_WP}'/" /tmp/mariadb.sql
sed -i "s/TO ''/TO '${USER_WP}'/" /tmp/mariadb.sql
sed -i "s/\*\.\*/WordPress\.\*/" /tmp/mariadb.sql
mysql < /tmp/mariadb.sql
# PhpMyAdmin User gets WordPress database access
sed -i '1d' /tmp/mariadb.sql
sed -i "s/USER '${USER_WP}'/USER '${USER_PMA}'/" /tmp/mariadb.sql
sed -i "s/BY '${PASSWORD_WP}'/BY '${PASSWORD_PMA}'/" /tmp/mariadb.sql
sed -i "s/TO '${USER_WP}'/TO '${USER_PMA}'/" /tmp/mariadb.sql
mysql < /tmp/mariadb.sql
# MariaDB user gets full access
sed -i "s/USER '${USER_PMA}'/USER '${USER_SVC}'/" /tmp/mariadb.sql
sed -i "s/BY '${PASSWORD_PMA}'/BY '${PASSWORD}'/" /tmp/mariadb.sql
sed -i "s/TO '${USER_PMA}'/TO '${USER_SVC}'/" /tmp/mariadb.sql
sed -i "s/WordPress\.\*/\*\.\*/" /tmp/mariadb.sql
mysql < /tmp/mariadb.sql
# PhpMyAdmin User gets PhpMyAdmin database access
sed -i "1,2d" /tmp/mariadb.sql
sed -i "s/USER '${USER_SVC}'/USER '${USER_PMA}'/" /tmp/mariadb.sql
sed -i "s/BY '${PASSWORD}'/BY '${PASSWORD_PMA}'/" /tmp/mariadb.sql
sed -i "s/TO '${USER_SVC}'/TO '${USER_PMA}'/" /tmp/mariadb.sql
sed -i "s/\*\.\*/phpmyadmin\.\*/" /tmp/mariadb.sql
mysql < /tmp/mariadb.sql
rm /tmp/mariadb.sql
sed -i "s/skip-networking/#skip-networking/" /etc/my.cnf.d/mariadb-server.cnf
sed -i "s/#bind-address=/bind-address=/" /etc/my.cnf.d/mariadb-server.cnf
service mariadb restart 2> /dev/null

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
sed -i 's/hostname = ""/hostname = "mariadb"/' /etc/telegraf/telegraf.conf
telegraf &

# Following command to avoid container to be terminated as soon as end of start up
sleep infinity
