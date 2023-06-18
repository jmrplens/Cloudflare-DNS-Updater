FROM alpine:3.18

LABEL maintainer="Jose Manuel Requena Plens <jmrplens@protonmail.com>"

RUN apk update && \
    apk upgrade && \
    apk add curl=8.1.2-r0
    

COPY ./update-cloudflare-records.sh /usr/local/bin
COPY ./update-cloudflare-records.yaml /usr/local/bin

RUN cp -a /usr/local/bin/update-cloudflare-records.sh /usr/local/bin/update-cloudflare-records
RUN rm -rf /usr/local/bin/update-cloudflare-records.sh
RUN chmod +x /usr/local/bin/update-cloudflare-records

CMD ["update-cloudflare-records"]
