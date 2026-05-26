#!/usr/bin/env bash
# Obtain, expand, or reconfigure wildcard certificate from Let's Encrypt via DNS-01
# Usage: ./get-cert.sh DOMAIN --provider domeneshop|cloudflare [--also DOMAIN2 ...] [--expand] [--reconfigure] [--production]
# Default: dry-run. Use --production to issue/expand a real certificate.
set -euo pipefail

if [ $# -lt 3 ]; then
    echo "Usage: $0 DOMAIN --provider domeneshop|cloudflare [--also DOMAIN2 ...] [--expand] [--reconfigure] [--production]" >&2
    echo "Example: $0 example.com --provider domeneshop                                             # dry-run" >&2
    echo "         $0 example.com --provider domeneshop --expand --also '*.ip.example.com' --production  # expand" >&2
    echo "         $0 example.org --provider cloudflare --reconfigure                        # change provider" >&2
    echo "         $0 example.net --provider cloudflare --also dev.example.net --production        # new cert" >&2
    exit 1
fi

# Load variables from .env if present
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

DOMAIN="$1"
if [ -z "${VPS_EMAIL_PRIVATE:-}" ]; then
    echo "Error: VPS_EMAIL_PRIVATE is not defined. Set it in .env" >&2
    exit 1
fi
EMAIL="$VPS_EMAIL_PRIVATE"
DRY_RUN="--dry-run"
EXPAND_FLAG=""
RECONFIGURE="false"
PROVIDER=""
EXTRA_DOMAINS=""

# Parse arguments
shift
while [ $# -gt 0 ]; do
    case "$1" in
        --provider)
            PROVIDER="$2"
            shift 2
            ;;
        --also)
            shift
            while [ $# -gt 0 ] && [[ "$1" != --* ]]; do
                EXTRA_DOMAINS="$EXTRA_DOMAINS -d $1 -d *.$1"
                shift
            done
            ;;
        --expand)
            EXPAND_FLAG="--expand"
            shift
            ;;
        --reconfigure)
            RECONFIGURE="true"
            shift
            ;;
        --production)
            DRY_RUN=""
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

if [ -z "$PROVIDER" ]; then
    echo "Error: --provider is required (domeneshop or cloudflare)" >&2
    exit 1
fi

case "$PROVIDER" in
    domeneshop)
        DNS_ARGS="--authenticator dns-domeneshop \
  --dns-domeneshop-credentials /secrets/domeneshop.ini \
  --dns-domeneshop-propagation-seconds 120"
        ;;
    cloudflare)
        DNS_ARGS="--authenticator dns-cloudflare \
  --dns-cloudflare-credentials /secrets/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 30"
        ;;
    *)
        echo "Error: unknown provider '$PROVIDER' (use domeneshop or cloudflare)" >&2
        exit 1
        ;;
esac

# Reconfigure: update renewal config provider without reissuing
if [ "$RECONFIGURE" = "true" ]; then
    echo "=== Reconfiguring renewal provider for ${DOMAIN} to ${PROVIDER} ==="
    docker exec vps-certbot certbot reconfigure \
      --cert-name "${DOMAIN}" \
      ${DNS_ARGS}
    echo "✓ Renewal config updated."
    exit 0
fi

if [ -n "$DRY_RUN" ]; then
    echo "=== Dry-run mode (no certificate will be issued) ==="
elif [ -n "$EXPAND_FLAG" ]; then
    echo "=== Production mode — expanding existing certificate ==="
else
    echo "=== Production mode ==="
fi

# For new certs (no --expand): check if cert exists and prompt to delete+reissue
if [ -z "$EXPAND_FLAG" ]; then
    if docker exec vps-certbot certbot certificates 2>/dev/null | grep -q "Certificate Name: ${DOMAIN}"; then
        echo ""
        echo "⚠ Certificate for ${DOMAIN} already exists!"
        echo ""
        docker exec vps-certbot certbot certificates --cert-name "${DOMAIN}"
        echo ""
        echo "Use --expand to add SANs, or delete and reissue?"
        read -p "Delete and reissue? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Deleting old certificate..."
            docker exec vps-certbot certbot delete --cert-name "${DOMAIN}"
        else
            echo "Aborted. Use --expand to add domains to an existing cert."
            exit 0
        fi
    fi
fi

echo ""
echo "Obtaining certificate for ${DOMAIN} and *.${DOMAIN}${EXTRA_DOMAINS:+ + extra domains}..."
echo ""

docker exec vps-certbot certbot certonly \
  ${DNS_ARGS} \
  ${DRY_RUN} \
  ${EXPAND_FLAG} \
  -d "${DOMAIN}" -d "*.${DOMAIN}" \
  ${EXTRA_DOMAINS} \
  --cert-name "${DOMAIN}" \
  --email "${EMAIL}" \
  --agree-tos --non-interactive

echo ""
if [ -n "$DRY_RUN" ]; then
    echo "✓ Dry-run successful!"
    echo ""
    echo "To issue a real certificate, add --production:"
    echo "  $0 ${DOMAIN} --provider ${PROVIDER}${EXPAND_FLAG:+ --expand}${EXTRA_DOMAINS:+ --also ...} --production"
elif [ -n "$EXPAND_FLAG" ]; then
    echo "✓ Certificate expanded!"
    echo "  Certificate: /etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
else
    echo "✓ Certificate obtained!"
    echo "  Certificate: /etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
    echo "  Private key: /etc/letsencrypt/live/${DOMAIN}/privkey.pem"
fi