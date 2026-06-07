FROM certbot/dns-cloudflare:latest

# Add Domeneshop plugin for multi-provider support, and cronie + docker CLI for scheduling
ARG CACHE_BYPASS
RUN pip install certbot-dns-domeneshop \
    && apk add --no-cache cronie docker-cli

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
