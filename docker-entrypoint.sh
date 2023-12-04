#!/bin/bash

set -e

# Function to resolve domain to IP
resolve_domain_to_ip() {
    local domain=$1
    local ip

    ip=$(dig +short "$domain" | head -n 1)
    if [[ -z "$ip" ]]; then
        echo "Error: Failed to resolve domain $domain"
        exit 1
    fi

    echo "$ip"
}

# If provided resolve TO_DOMAIN to IP and set it to TO_ADDR
if [[ -n "$TO_DOMAIN" ]]; then
    TO_ADDR=$(resolve_domain_to_ip "$TO_DOMAIN")
fi

# Default values for ACCEPT_UIDS and ACCEPT_GIDS
DEFAULT_ACCEPT_UIDS="1010"  # Default UID of Qtap
DEFAULT_ACCEPT_GIDS="1010"  # Default GID of Qtap
DEFAULT_PORT_MAPPING="10080:80,10443:443,10000:"
DEFAULT_ACCEPT_BLOCKS="127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"  # loopback and RFC 1918 address blocks

# Set default values if they are not provided
ACCEPT_UIDS="${ACCEPT_UIDS:-$DEFAULT_ACCEPT_UIDS}"
ACCEPT_GIDS="${ACCEPT_GIDS:-$DEFAULT_ACCEPT_GIDS}"
PORT_MAPPING="${PORT_MAPPING:-$DEFAULT_PORT_MAPPING}"
ACCEPT_BLOCKS="${ACCEPT_BLOCKS:-$DEFAULT_ACCEPT_BLOCKS}"

echo "----->"
echo "ACCEPT_UIDS: $ACCEPT_UIDS"
echo "ACCEPT_GIDS: $ACCEPT_GIDS"
echo "PORT_MAPPING: $PORT_MAPPING"
echo "ACCEPT_BLOCKS: $ACCEPT_BLOCKS"
echo "<-----"

apply_rules() {
    local TO_PORT="$1"
    local DEST_PORT="$2"

    local PORT_SPECIFIER=""
    if [[ -n "$DEST_PORT" ]]; then
        PORT_SPECIFIER="--dport $DEST_PORT"
    fi

    # Apply rules for UIDs
    IFS=',' read -ra UIDS <<< "$ACCEPT_UIDS"
    for USER_ID in "${UIDS[@]}"; do
        iptables -t nat -A OUTPUT -p tcp $PORT_SPECIFIER -m owner --uid-owner "$USER_ID" -j ACCEPT
    done

    # Apply rules for GIDs
    IFS=',' read -ra GIDS <<< "$ACCEPT_GIDS"
    for GROUP_ID in "${GIDS[@]}"; do
        iptables -t nat -A OUTPUT -p tcp $PORT_SPECIFIER -m owner --gid-owner "$GROUP_ID" -j ACCEPT
    done

    # Apply redirect or DNAT rule
    if [[ -n "$TO_ADDR" ]]; then
        iptables -t nat -A OUTPUT -p tcp $PORT_SPECIFIER -j DNAT --to-destination "$TO_ADDR:$TO_PORT"
    else
        iptables -t nat -A OUTPUT -p tcp $PORT_SPECIFIER -j REDIRECT --to-port "$TO_PORT"
    fi
}

# Apply rules for each block
IFS=',' read -ra BLOCKS <<< "$ACCEPT_BLOCKS"
for BLOCK in "${BLOCKS[@]}"; do
    iptables -t nat -A OUTPUT -p tcp -d "$BLOCK" -j ACCEPT
done

IFS=',' read -ra MAPPINGS <<< "$PORT_MAPPING"
for MAPPING in "${MAPPINGS[@]}"; do
    IFS=':' read -ra PORTS <<< "$MAPPING"
    TO_PORT="${PORTS[0]}"
    DEST_PORT="${PORTS[1]}"

    apply_rules "$TO_PORT" "$DEST_PORT"
done

# Ensure the rules are set
iptables -t nat -L -n -v
