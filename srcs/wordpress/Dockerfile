FROM alpine:latest
LABEL maintainer="acoudert@student.42.fr"
# --no-cache recommended to keep container light weighted
RUN apk update && apk upgrade
RUN apk add --no-cache \
	nginx \
	php7-fpm \
	php7-common \
	php7-opcache \
	php7-zlib \
	php7-phar \
	php7-sockets \
	php7-iconv \
	php7-json \
	php7-gd \
	php7-curl \
	php7-xml \
	php7-mysqli \
	php7-imap \
	php7-cgi \
	fcgi \
	php7-pdo \
	php7-pdo_mysql \
	php7-soap \
	php7-xmlrpc \
	php7-posix \
	php7-mcrypt \
	php7-gettext \
	php7-ldap \
	php7-ctype \
	php7-dom \
	mysql \
	mysql-client \
	openssl \
	wget \
	curl \
	openrc \
	vim
COPY init_wordpress.sh /tmp
COPY liveness.sh /tmp
COPY wp-config.php /tmp
COPY wordpress.conf /etc/nginx/conf.d/
CMD ["sh", "/tmp/init_wordpress.sh"]
