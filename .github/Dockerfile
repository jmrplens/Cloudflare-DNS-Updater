FROM alpine:3.18@sha256:7144f7bab3d4c2648d7e59409f15ec52a18006a128c733fcff20d3a4a54ba44a

LABEL maintainer="Jose Manuel Requena Plens <jmrplens@protonmail.com>"

RUN apk --no-cache add curl=8.1.2-r0


COPY ./cloudflare-dns.sh /usr/local/bin
COPY ./cloudflare-dns.yaml /usr/local/bin

RUN cp -a /usr/local/bin/cloudflare-dns.sh /usr/local/bin/cloudflare-dns
RUN rm -rf /usr/local/bin/cloudflare-dns.sh
RUN chmod +x /usr/local/bin/cloudflare-dns

CMD ["cloudflare-dns dydns-update"]
