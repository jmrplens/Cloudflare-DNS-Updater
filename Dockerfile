FROM ubuntu:latest

LABEL maintainer="Jose Manuel Requena Plens <jmrplens@protonmail.com>"

RUN apt-get update && apt-get install -y \
    curl \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*
    

COPY ./update-cloudflare-records.sh /usr/local/bin/update-cloudflare-records
COPY ./update-cloudflare-records.yaml /usr/local/bin

RUN chmod +x /usr/local/bin/update-cloudflare-records

CMD ["update-cloudflare-records"]
