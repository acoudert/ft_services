#!/bin/sh

if [ $(service nginx status | grep 'started' | wc -l) -ne 1 ] \
	|| [ $(service php-fpm7 | grep 'started' | wc -l) -ne 1 ]; then
	exit 1
fi
exit 0
