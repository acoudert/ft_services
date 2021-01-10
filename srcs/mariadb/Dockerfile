FROM alpine:latest
LABEL maintainer="acoudert@student.42.fr"
# --no-cache recommended to keep container light weighted
RUN apk update && apk upgrade
RUN apk add --no-cache \
	mariadb \
	mariadb-client \
	wget \
	openrc \
	vim
COPY init_mariadb.sh /tmp
COPY liveness.sh /tmp
COPY mariadb.sql /tmp/mariadb.sql
CMD ["sh", "/tmp/init_mariadb.sh"]
