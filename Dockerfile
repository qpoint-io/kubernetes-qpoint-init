FROM alpine:3.18

RUN apk add --no-cache iptables bash && rm -rf /var/cache/apk/*

COPY docker-entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
