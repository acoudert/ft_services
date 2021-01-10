FROM alpine:latest
LABEL maintainer="acoudert@student.42.fr"
# --no-cache recommended to keep container light weighted
RUN apk update && apk upgrade
RUN apk add --no-cache \
	sqlite \
	wget \
	openssl \
	openrc \
	vim
COPY init_grafana.sh /tmp
COPY liveness.sh /tmp
COPY grafana.db /tmp
CMD ["sh", "/tmp/init_grafana.sh"]
