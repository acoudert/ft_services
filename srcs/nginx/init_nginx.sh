#!/bin/sh

# NGINX
# Allow to run openrc service on a system not booted by openrc
mkdir -p /run/openrc
touch /run/openrc/softlevel
# Create server root directory and add default page
mkdir /var/www/nginx-server
mv /tmp/index.html /var/www/nginx-server
# Only /etc/nginx/conf.d/*.conf file loaded as per /etc/nginx/nginx.conf
mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak
# Create certificate and key for TLS
openssl req -nodes -x509 -newkey rsa:2048 -keyout /etc/ssl/private/key.pem -out /etc/ssl/certs/cert.pem -days 182 -subj "/C=FR/ST=Paris/L=Paris/O=42/OU=42student/CN=nginx-server.com"
# Change runlevel to allow nginx start up
openrc 2> /dev/null
# Start nginx service
service nginx start 2> /dev/null

# SSH
# Create user and set up password
adduser -D $USER_SVC
echo -e "$PASSWORD\n$PASSWORD" | passwd $USER_SVC
# Allow user-ssh to login through ssh
echo "AllowUsers $USER_SVC" >> /etc/ssh/sshd_config
# Update message of the day
echo "Welcome $USER_SVC to the nginx-server" > /etc/motd
# Start sshd service
service sshd start 2> /dev/null

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
sed -i 's/hostname = ""/hostname = "nginx"/' /etc/telegraf/telegraf.conf
telegraf &

# Following command to avoid container to be terminated as soon as end of start up
sleep infinity
