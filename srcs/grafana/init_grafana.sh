#!/bin/sh

# Allow to run openrc service on a system not booted by openrc
mkdir -p /run/openrc
touch /run/openrc/softlevel
openrc 2> /dev/null

# Grafana
while true; do
	wget -P /tmp -T 15 -c \
		"https://dl.grafana.com/oss/release/grafana-7.3.6.linux-amd64.tar.gz" \
	       	&& break
done
tar -xf /tmp/grafana-7.3.6.linux-amd64.tar.gz -C /tmp && mv /tmp/grafana-7.3.6 /tmp/grafana
# For musl glibc (Go dependencies)
mkdir /lib64 && ln -s /lib/libc.musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2
openssl req -nodes -x509 -newkey rsa:2048 -keyout /etc/ssl/private/key.pem -out /etc/ssl/certs/cert.pem -days 182 -subj "/C=FR/ST=Paris/L=Paris/O=42/OU=42student/CN=Grafana.com"
cp -R /tmp/grafana/conf /etc/grafana
cp /etc/grafana/defaults.ini /etc/grafana/grafana.ini
cp /tmp/grafana/bin/grafana-cli /usr/bin/grafana-cli
cp /tmp/grafana/bin/grafana-server /usr/bin/grafana-server
mv /tmp/grafana/* /usr/share/grafana/
sed -i "s/protocol = http/protocol = https/" /etc/grafana/grafana.ini
sed -i "s/cert_file =/cert_file = \/etc\/ssl\/certs\/cert.pem/" /etc/grafana/grafana.ini
sed -i "s/cert_key =/cert_key = \/etc\/ssl\/private\/key.pem/" /etc/grafana/grafana.ini
sed -i "s/admin_user = admin/admin_user = ${USER_SVC}/" /etc/grafana/grafana.ini
cp /tmp/grafana.db /usr/share/grafana/data/grafana.db
chmod 640 /usr/share/grafana/data/grafana.db
grafana-server --homepath=/usr/share/grafana/ --config=/etc/grafana/grafana.ini &> /dev/null &

# Telegraf sidecar
while true; do
	wget -P /tmp -T 15 -c \
		"https://dl.influxdata.com/telegraf/releases/telegraf-1.17.0_linux_amd64.tar.gz" \
	       	&& break
done
tar -xf /tmp/telegraf-1.17.0_linux_amd64.tar.gz -C /tmp && mv /tmp/telegraf-1.17.0 /tmp/telegraf
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
sed -i 's/hostname = ""/hostname = "grafana"/' /etc/telegraf/telegraf.conf
telegraf &

# Following command to avoid container to be terminated as soon as end of start up
sleep infinity
