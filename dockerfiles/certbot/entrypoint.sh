#!/bin/sh
set -e

# Fix ownership so cronie accepts the files (container runs as root)
chown root:root /etc/cron.d/*
chmod 644 /etc/cron.d/*

# Ensure deploy hooks are executable
chmod +x /etc/letsencrypt/renewal-hooks/deploy/*.sh 2>/dev/null || true

exec crond -n
