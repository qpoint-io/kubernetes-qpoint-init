FROM alpine:3.20

RUN apk add --no-cache bash bind-tools iptables && rm -rf /var/cache/apk/*

COPY docker-entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
