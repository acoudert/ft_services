FROM alpine:latest
LABEL maintainer="acoudert@student.42.fr"
# --no-cache recommended to keep container light weighted
RUN apk update && apk upgrade
RUN apk add --no-cache \
	influxdb \
	wget \
	openrc \
	vim
COPY init_influxdb.sh /tmp
COPY liveness.sh /tmp
CMD ["sh", "/tmp/init_influxdb.sh"]
