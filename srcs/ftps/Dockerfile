FROM alpine:latest
LABEL maintainer="acoudert@student.42.fr"
# --no-cache recommended to keep container light weighted
RUN apk update && apk upgrade
RUN apk add --no-cache \
	vsftpd \
	wget \
	openssl \
	openrc \
	vim
COPY srcs/ftps/init_ftps.sh /tmp
COPY srcs/ftps/liveness.sh /tmp
COPY . /tmp/ftps/
CMD ["sh", "/tmp/init_ftps.sh"]
