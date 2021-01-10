#!/bin/sh

if [ $(ps | grep grafana | wc -l) -ne 3 ]; then
	exit 1
fi
exit 0
