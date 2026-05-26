#!/bin/bash
# check-dns.sh - verify A/AAAA records point to the new server
# Usage: ./scripts/check-dns.sh [domain ...]

# Load variables from .env if present
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Validate required variables
if [ -z "${VPS_IPV4:-}" ]; then echo "Error: VPS_IPV4 is not defined in .env" >&2; exit 1; fi
if [ -z "${VPS_DOMAINS:-}" ]; then echo "Error: VPS_DOMAINS is not defined in .env" >&2; exit 1; fi

EXPECTED_A="$VPS_IPV4"
EXPECTED_AAAA="${VPS_IPV6:-}" # IPv6 is optional
RESOLVER="${RESOLVER:-@1.1.1.1}"

# Load domains from comma-separated list
IFS=',' read -r -a STATIC_DOMAINS <<< "$VPS_DOMAINS"

# Build domain→certname map and cert expiry days from certbot certificates output
declare -A DOMAIN_CERT
declare -A CERT_DAYS
current_cert=""
while IFS= read -r line; do
    if [[ "$line" =~ "Certificate Name: "(.+) ]]; then
        current_cert="${BASH_REMATCH[1]}"
    elif [[ -n "$current_cert" && "$line" =~ "Identifiers: "(.+) ]]; then
        for d in ${BASH_REMATCH[1]}; do
            DOMAIN_CERT["${d#\*.}"]="$current_cert"
        done
    elif [[ -n "$current_cert" && "$line" =~ "VALID: "([0-9]+)" day" ]]; then
        CERT_DAYS["$current_cert"]="${BASH_REMATCH[1]}d"
    elif [[ -n "$current_cert" && "$line" =~ "EXPIRED" ]]; then
        CERT_DAYS["$current_cert"]="EXP"
    fi
done < <(docker exec vps-certbot certbot certificates 2>/dev/null)

if [[ $# -gt 0 ]]; then
    DOMAINS=("$@")
else
    # Merge static list + cert-discovered domains, deduplicate, sort
    declare -A _seen
    _all=("${STATIC_DOMAINS[@]}" "${!DOMAIN_CERT[@]}")
    for d in "${_all[@]}"; do
        [[ -z "${_seen[$d]+x}" ]] && _seen[$d]=1
    done
    IFS=$'\n' DOMAINS=($(sort <<<"${!_seen[*]}")); unset IFS
fi

get_cert_provider() {
    local certname="${DOMAIN_CERT[$1]}"
    local conf="/etc/letsencrypt/renewal/${certname:-$1}.conf"
    local plugin
    plugin=$(docker exec vps-certbot grep -o "authenticator = dns-[a-z]*" "$conf" 2>/dev/null | grep -o "[a-z]*$" | head -1)
    echo "${plugin:-none}"
}

chk() {
    local actual
    actual=$(dig +short "$2" "$1" $RESOLVER | head -1)
    [[ "$actual" == "$3" ]] && echo "OK" || echo "--"
}

printf "%-22.22s %-18.18s %-40.40s %-6s %-14.14s %-5s %-4s %-4s %-4s %-5s\n" \
    "Domain" "Registrar" "Auth NS" "DNSSEC" "Cert" "Days" "A" "AAAA" "A*" "AAAA*"
printf "%-22.22s %-18.18s %-40.40s %-6s %-14.14s %-5s %-4s %-4s %-4s %-5s\n" \
    "------" "---------" "-------" "------" "----" "----" "--" "----" "--" "-----"

for domain in "${DOMAINS[@]}"; do
    rdap=$(curl -sL --max-time 8 "https://rdap.org/domain/$domain" 2>/dev/null)
    registrar=$(echo "$rdap" | jq -r '[.entities[]? | select(.roles[]? == "registrar") | .vcardArray[1][]? | select(.[0] == "fn") | .[3]] | first // "?"' 2>/dev/null)
    ns=$(echo "$rdap" | jq -r '[.nameservers[]?.ldhName | ascii_downcase] | sort | join(",") | if . == "" then "?" else . end' 2>/dev/null)
    dnssec=$(echo "$rdap" | jq -r 'if .secureDNS.delegationSigned == true then "yes" else "no" end' 2>/dev/null)
    cert=$(get_cert_provider "$domain")
    days="${CERT_DAYS[${DOMAIN_CERT[$domain]}]:-?}"
    a=$(chk    "$domain"     A    "$EXPECTED_A")
    aaaa=$(chk "$domain"     AAAA "$EXPECTED_AAAA")
    aw=$(chk   "foo.$domain" A    "$EXPECTED_A")
    aaaaw=$(chk "foo.$domain" AAAA "$EXPECTED_AAAA")
    printf "%-22.22s %-18.18s %-40.40s %-6s %-14.14s %-5s %-4s %-4s %-4s %-5s\n" \
        "$domain" "${registrar:-?}" "${ns:-?}" "${dnssec:-?}" "$cert" "$days" "$a" "$aaaa" "$aw" "$aaaaw"
done
