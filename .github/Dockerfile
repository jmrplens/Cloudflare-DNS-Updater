FROM alpine:3.18@sha256:82d1e9d7ed48a7523bdebc18cf6290bdb97b82302a8a9c27d4fe885949ea94d1

LABEL maintainer="Jose Manuel Requena Plens <jmrplens@protonmail.com>"

RUN apk --no-cache add curl=8.1.2-r0


COPY ./cloudflare-dns.sh /usr/local/bin
COPY ./cloudflare-dns.yaml /usr/local/bin

RUN cp -a /usr/local/bin/cloudflare-dns.sh /usr/local/bin/cloudflare-dns
RUN rm -rf /usr/local/bin/cloudflare-dns.sh
RUN chmod +x /usr/local/bin/cloudflare-dns

CMD ["cloudflare-dns dydns-update"]
