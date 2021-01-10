FROM alpine:latest
LABEL maintainer="acoudert@student.42.fr"
# --no-cache recommended to keep container light weighted
RUN apk update && apk upgrade
RUN apk add --no-cache \
	nginx \
	php7-fpm \
	php7-session \
	php7-sockets \
	php7-mbstring \
	php7-common \
	php7-opcache \
	php7-zlib \
	php7-json \
	php7-gd \
	php7-curl \
	php7-xml \
	php7-mysqli \
	php7-cgi \
	php7-mcrypt \
	mysql \
	mysql-client \
	wget \
	openssl \
	openrc \
	vim
COPY init_phpmyadmin.sh /tmp
COPY liveness.sh /tmp
COPY config.inc.php /tmp 
COPY phpmyadmin.conf /etc/nginx/conf.d
CMD ["sh", "/tmp/init_phpmyadmin.sh"]
