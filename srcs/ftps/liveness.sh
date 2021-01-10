#!/bin/sh

if [ $(service vsftpd status | grep 'started' | wc -l) -ne 1 ]; then
	exit 1
fi
exit 0
