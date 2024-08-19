FROM alpine:3.20@sha256:0a4eaa0eecf5f8c050e5bba433f58c052be7587ee8af3e8b3910ef9ab5fbe9f5

LABEL maintainer="Jose Manuel Requena Plens <jmrplens@protonmail.com>"

RUN apk --no-cache add curl=8.1.2-r0


COPY ./cloudflare-dns.sh /usr/local/bin
COPY ./cloudflare-dns.yaml /usr/local/bin

RUN cp -a /usr/local/bin/cloudflare-dns.sh /usr/local/bin/cloudflare-dns
RUN rm -rf /usr/local/bin/cloudflare-dns.sh
RUN chmod +x /usr/local/bin/cloudflare-dns

CMD ["cloudflare-dns dydns-update"]
