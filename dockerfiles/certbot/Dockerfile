FROM certbot/dns-cloudflare:latest

# Add Domeneshop plugin and Docker CLI for renewal hooks.
ARG CACHE_BYPASS
RUN pip install certbot-dns-domeneshop \
    && apk add --no-cache \
    bash \
    docker-cli \
    tzdata

COPY entrypoint.sh /entrypoint.sh
COPY reload-containers.sh /usr/local/libexec/reload-containers.sh
RUN chmod +x /entrypoint.sh

ENV TZ="Europe/Oslo"
ENV CERTBOT_RENEW_SCHEDULE="0 1 * * *"

ENTRYPOINT ["/entrypoint.sh"]
