#!/bin/sh

mkdir -p /run/openrc
touch /run/openrc/softlevel
openssl req -nodes -x509 -newkey rsa:2048 -keyout /etc/ssl/private/key.pem -out /etc/ssl/certs/cert.pem -days 182 -subj "/C=FR/ST=Paris/L=Paris/O=42/OU=42student/CN=ftps-server.com"
openrc 2> /dev/null
adduser -D $USER_SVC
echo -e "$PASSWORD\n$PASSWORD" | passwd $USER_SVC

sed -i 's/#ftpd_banner=Welcome to blah FTP service\./ftpd_banner=Welcome to the ftps-server\./' \
	/etc/vsftpd/vsftpd.conf
# Following line to avoid OOPS error
echo 'seccomp_sandbox=NO' >> /etc/vsftpd/vsftpd.conf
# Passive connection setup
echo 'pasv_enable=YES' >> /etc/vsftpd/vsftpd.conf
echo "pasv_address=235" >> /etc/vsftpd/vsftpd.conf
echo 'pasv_min_port=10000' >> /etc/vsftpd/vsftpd.conf
echo 'pasv_max_port=10000' >> /etc/vsftpd/vsftpd.conf
# TLS
echo 'ssl_enable=YES' >> /etc/vsftpd/vsftpd.conf
echo 'ssl_tlsv1=YES' >> /etc/vsftpd/vsftpd.conf
echo 'ssl_sslv2=NO' >> /etc/vsftpd/vsftpd.conf
echo 'ssl_sslv3=NO' >> /etc/vsftpd/vsftpd.conf
echo 'force_local_data_ssl=YES' >> /etc/vsftpd/vsftpd.conf
echo 'force_local_logins_ssl=YES' >> /etc/vsftpd/vsftpd.conf
echo 'rsa_cert_file=/etc/ssl/certs/cert.pem' >> /etc/vsftpd/vsftpd.conf
echo 'rsa_private_key_file=/etc/ssl/private/key.pem' >> /etc/vsftpd/vsftpd.conf
# User
sed -i 's/anonymous_enable=YES/anonymous_enable=NO/' /etc/vsftpd/vsftpd.conf
sed -i 's/#local_enable=YES/local_enable=YES/' /etc/vsftpd/vsftpd.conf
sed -i 's/#write_enable=YES/write_enable=YES/' /etc/vsftpd/vsftpd.conf
# Directory content
mv /tmp/ftps/* /home/user_ftps/
service vsftpd start

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
sed -i 's/hostname = ""/hostname = "ftps"/' /etc/telegraf/telegraf.conf
telegraf &

# Following command to avoid container to be terminated as soon as end of start up
sleep infinity
