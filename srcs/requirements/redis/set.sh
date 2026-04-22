#!/bin/sh

REDIS_PASSWORD=$(cat /run/secrets/redis_password)

exec redis-server /usr/local/etc/redis/redis.conf --requirepass "$REDIS_PASSWORD"
