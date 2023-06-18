FROM alpine:latest

LABEL maintainer="Jose Manuel Requena Plens <jmrplens@protonmail.com>"

RUN apt-get update && apt-get install -y \
    curl \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*
    

COPY ./update-cloudflare-records.sh /usr/local/bin
COPY ./update-cloudflare-records.yaml /usr/local/bin

RUN cp -a /usr/local/bin/update-cloudflare-records.sh /usr/local/bin/update-cloudflare-records
RUN rm -rf /usr/local/bin/update-cloudflare-records.sh
RUN chmod +x /usr/local/bin/update-cloudflare-records

CMD ["update-cloudflare-records"]
