FROM alpine:3.20@sha256:beefdbd8a1da6d2915566fde36db9db0b524eb737fc57cd1367effd16dc0d06d

LABEL maintainer="Jose Manuel Requena Plens <jmrplens@protonmail.com>"

RUN apk --no-cache add curl=8.1.2-r0


COPY ./cloudflare-dns.sh /usr/local/bin
COPY ./cloudflare-dns.yaml /usr/local/bin

RUN cp -a /usr/local/bin/cloudflare-dns.sh /usr/local/bin/cloudflare-dns
RUN rm -rf /usr/local/bin/cloudflare-dns.sh
RUN chmod +x /usr/local/bin/cloudflare-dns

CMD ["cloudflare-dns dydns-update"]
