FROM alpine:3.19

# Create the icecast user with a deterministic UID/GID before installing
# This guarantees perfectly stable permissions for host volume mounts
RUN addgroup -g 1000 icecast && \
    adduser -u 1000 -G icecast -h /var/log/icecast -s /sbin/nologin -D icecast

# Install Icecast and necessary tools
RUN apk add --no-cache icecast bash

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose ports
EXPOSE 8000 8443

# Icecast will start as root, then internally drop privileges to 'icecast'
# via its <security> configuration.
CMD ["/entrypoint.sh"]
