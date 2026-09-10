#!/usr/bin/env bash
set -Eeuo pipefail
set +x

umask 077

API_BASE="${CLOUDFLARE_API_BASE:-https://api.cloudflare.com/client/v4}"
API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"
ZONE_NAME="${CLOUDFLARE_ZONE:-swirlit.dev}"
HOST_LABEL="${CLOUDFLARE_HOST_LABEL:-devapp}"
ORIGIN_IP="${CLOUDFLARE_ORIGIN_IP:-}"
INGRESS_NAMESPACE="${INGRESS_NAMESPACE:-infra}"
INGRESS_SERVICE="${INGRESS_SERVICE:-ingress-nginx-controller}"
WORK_DIR=""
CURL_CONFIG=""

info() { printf '[INFO] %s\n' "$*"; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage: infra/scripts/configure-cloudflare.sh [options]

Reconciles the proxied public DNS record owned by DevApp. Shared zone, TLS,
ingress, and Cloudflare security configuration remain platform responsibilities.
Uses the published HA Tunnel when configured, otherwise the direct ingress IP.

Options:
  --zone DOMAIN       Cloudflare zone (default: swirlit.dev)
  --host-label LABEL  DevApp hostname label (default: devapp)
  --origin-ip IP      Direct-mode NGINX IPv4; discovered when omitted
  -h, --help          Show this help

Secret input:
  Set CLOUDFLARE_API_TOKEN or enter a Cloudflare User API Token when prompted.
  The token needs Zone:Read and DNS:Edit for the selected zone.
EOF
}

cleanup() {
    API_TOKEN=""
    unset CLOUDFLARE_API_TOKEN || true
    if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
        rm -f "$WORK_DIR"/*
        rmdir "$WORK_DIR" 2>/dev/null || true
    fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
    case "$1" in
        --zone)
            [[ $# -ge 2 ]] || fail "--zone requires a value"
            ZONE_NAME="$2"
            shift 2
            ;;
        --host-label)
            [[ $# -ge 2 ]] || fail "--host-label requires a value"
            HOST_LABEL="$2"
            shift 2
            ;;
        --origin-ip)
            [[ $# -ge 2 ]] || fail "--origin-ip requires a value"
            ORIGIN_IP="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "Unknown option: $1"
            ;;
    esac
done

ZONE_NAME="${ZONE_NAME,,}"
HOST_LABEL="${HOST_LABEL,,}"
[[ "$ZONE_NAME" =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$ ]] || \
    fail "Invalid zone name: $ZONE_NAME"
[[ "$HOST_LABEL" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || \
    fail "Invalid hostname label: $HOST_LABEL"

for command_name in curl jq kubectl; do
    command -v "$command_name" >/dev/null 2>&1 || fail "$command_name is required"
done

ingress_state="$(kubectl get configmap bm-cluster-public-ingress -n "$INGRESS_NAMESPACE" \
    --ignore-not-found --request-timeout=15s -o json)" || fail "Cannot verify the platform ingress mode"
if [[ -n "$ingress_state" ]]; then
    ingress_mode="$(jq -er '.data.mode | select(type == "string" and length > 0)' <<< "$ingress_state")" || \
        fail "Existing platform ingress state has no valid mode"
else
    ingress_mode=direct
fi
case "$ingress_mode" in
    tunnel)
        [[ -z "$ORIGIN_IP" ]] || fail "--origin-ip cannot override HA Tunnel routing"
        tunnel_id="$(jq -r '.data.tunnelID // ""' <<< "$ingress_state")"
        [[ "$tunnel_id" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]] || \
            fail "Invalid platform Tunnel ID"
        jq -e --arg id "$tunnel_id" --arg domain "$ZONE_NAME" \
            '.data.publishedTunnelID == $id and .data.domain == $domain' \
            <<< "$ingress_state" >/dev/null || fail "The HA Tunnel is not published for this zone yet"
        record_type=CNAME
        record_content="$tunnel_id.cfargotunnel.com"
        ;;
    direct)
        if [[ -z "$ORIGIN_IP" ]]; then
            ORIGIN_IP="$(kubectl get service "$INGRESS_SERVICE" -n "$INGRESS_NAMESPACE" \
                -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
        fi
        [[ "$ORIGIN_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || \
            fail "Could not discover a valid public IPv4; use --origin-ip"
        IFS=. read -r octet1 octet2 octet3 octet4 <<< "$ORIGIN_IP"
        for octet in "$octet1" "$octet2" "$octet3" "$octet4"; do
            ((10#$octet <= 255)) || fail "Invalid IPv4 address: $ORIGIN_IP"
        done
        record_type=A
        record_content="$ORIGIN_IP"
        ;;
    *) fail "Unknown platform ingress mode: $ingress_mode" ;;
esac

if [[ -z "$API_TOKEN" ]]; then
    [[ -t 0 ]] || fail "Set CLOUDFLARE_API_TOKEN for non-interactive use"
    read -rsp "Cloudflare User API Token: " API_TOKEN
    printf '\n' >&2
fi
[[ "$API_TOKEN" == cfut_* ]] || fail "Expected a Cloudflare User API Token beginning with cfut_"
[[ "$API_TOKEN" =~ ^cfut_[[:graph:]]+$ && "$API_TOKEN" != *\"* && "$API_TOKEN" != *\\* ]] || \
    fail "Token must be a single value without whitespace, quotes, or backslashes"

WORK_DIR="$(mktemp -d /tmp/devapp-cloudflare.XXXXXX)"
CURL_CONFIG="$WORK_DIR/curl.conf"
printf 'silent\nshow-error\nheader = "Authorization: Bearer %s"\n' "$API_TOKEN" > "$CURL_CONFIG"
chmod 600 "$CURL_CONFIG"

cf_request() {
    local method="$1"
    local path="$2"
    local data_file="${3:-}"
    local curl_args=(
        --config "$CURL_CONFIG"
        --request "$method"
        --url "$API_BASE$path"
        --header "Content-Type: application/json"
    )
    if [[ -n "$data_file" ]]; then
        curl_args+=(--data-binary "@$data_file")
    fi
    curl "${curl_args[@]}"
}

require_success() {
    local response="$1"
    local operation="$2"
    if ! jq -e '.success == true' <<< "$response" >/dev/null 2>&1; then
        local details
        details="$(jq -r '[.errors[]?.message, .messages[]?.message] | map(select(. != null and . != "")) | join("; ")' \
            <<< "$response" 2>/dev/null || true)"
        details="${details//"$API_TOKEN"/[redacted]}"
        fail "$operation failed${details:+: $details}"
    fi
}

zone_response="$(cf_request GET "/zones?name=$ZONE_NAME&per_page=100")"
require_success "$zone_response" "Looking up Cloudflare zone $ZONE_NAME"
zone_count="$(jq '.result | length' <<< "$zone_response")"
((zone_count == 1)) || fail "Expected exactly one Cloudflare zone named $ZONE_NAME; found $zone_count"
zone_id="$(jq -r '.result[0].id' <<< "$zone_response")"

fqdn="$HOST_LABEL.$ZONE_NAME"
record_response="$(cf_request GET "/zones/$zone_id/dns_records?name=$fqdn&per_page=100")"
require_success "$record_response" "Looking up DNS record $fqdn"
address_record_count="$(jq '[.result[] | select(.type == "A" or .type == "AAAA" or .type == "CNAME")] | length' \
    <<< "$record_response")"
((address_record_count <= 1)) || fail "$fqdn has multiple address records; reconcile them before rerunning"

record_file="$WORK_DIR/dns.json"
jq -n --arg name "$fqdn" --arg content "$record_content" --arg type "$record_type" \
    '{type:$type,name:$name,content:$content,ttl:1,proxied:true,comment:"Managed by devapp/infra/scripts/configure-cloudflare.sh"}' \
    > "$record_file"

if ((address_record_count == 0)); then
    update_response="$(cf_request POST "/zones/$zone_id/dns_records" "$record_file")"
    require_success "$update_response" "Creating DNS record $fqdn"
    info "Created $fqdn -> $record_content (proxied)"
    exit 0
fi

current_record="$(jq -c '[.result[] | select(.type == "A" or .type == "AAAA" or .type == "CNAME")][0]' \
    <<< "$record_response")"
if jq -e --arg content "$record_content" --arg type "$record_type" \
    '.type == $type and .content == $content and .proxied == true and .ttl == 1' \
    <<< "$current_record" >/dev/null; then
    info "DNS record already correct: $fqdn"
    exit 0
fi

record_id="$(jq -r '.id' <<< "$current_record")"
update_response="$(cf_request PUT "/zones/$zone_id/dns_records/$record_id" "$record_file")"
require_success "$update_response" "Updating DNS record $fqdn"
info "Updated $fqdn -> $record_content (proxied)"
