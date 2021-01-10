#!/bin/sh

if [ $(service nginx status | grep 'started' | wc -l) -ne 1 ] \
	|| [ $(service sshd status | grep 'started' | wc -l) -ne 1 ]; then
	exit 1
fi
exit 0
