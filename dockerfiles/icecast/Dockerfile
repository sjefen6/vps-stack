FROM alpine:latest

RUN apk add --no-cache icecast bash

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose ports
EXPOSE 8000 8443

# Icecast will start as root, then internally drop privileges to 'icecast'
# via its <security> configuration.
CMD ["/entrypoint.sh"]
