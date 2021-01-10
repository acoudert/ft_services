FROM alpine:latest
LABEL maintainer="acoudert@student.42.fr"
# --no-cache recommended to keep container light weighted
RUN apk update && apk upgrade
RUN apk add --no-cache \
	openssh \
	nginx \
	wget \
	openssl \
	openrc \
	vim
COPY init_nginx.sh /tmp
COPY liveness.sh /tmp
COPY nginx-server.conf /etc/nginx/conf.d/
COPY index.html /tmp
CMD ["sh", "/tmp/init_nginx.sh"]
