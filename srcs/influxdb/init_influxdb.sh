#!/bin/sh

# Allow to run openrc service on a system not booted by openrc
mkdir -p /run/openrc
touch /run/openrc/softlevel
# Change runlevel to allow mariadb start up
openrc 2> /dev/null
# Setup time based database
service influxdb start
sleep 2
echo "CREATE USER ${USER_SVC} WITH PASSWORD '${PASSWORD}' WITH ALL PRIVILEGES" | influx
echo "CREATE DATABASE telegraf" | influx
sed -i 's/# enabled = true/enabled = true/' /etc/influxdb.conf
sed -i 's/# bind-address = ":8086"/bind-address = ":8086"/' /etc/influxdb.conf
sed -i 's/# auth-enabled = false/auth-enabled = true/' /etc/influxdb.conf
service influxdb restart

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
sed -i "s/# username = \"telegraf\"/username = \"${USER_METRICS}\"/" \
	/etc/telegraf/telegraf.conf
sed -i "s/# password = \"metricsmetricsmetricsmetrics\"/password = \"${PASS_METRICS}\"/" \
	/etc/telegraf/telegraf.conf
sed -i 's/hostname = ""/hostname = "influxdb"/' /etc/telegraf/telegraf.conf
telegraf &

# Following command to avoid container to be terminated as soon as end of start up
sleep infinity
