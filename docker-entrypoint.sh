#!/bin/bash

set -e

if [[ -n "$TO_DOMAIN" ]]; then
    TO_ADDR=$(dig +short "$TO_DOMAIN" | head -n 1)
fi

# Default values for ACCEPT_UIDS and ACCEPT_GIDS
DEFAULT_ACCEPT_UIDS="1010"  # Default UID of Qtap
DEFAULT_ACCEPT_GIDS="1010"  # Default GID of Qtap
DEFAULT_PORT_MAPPING="10080:80,10443:443,10000:"

# Set default values for ACCEPT_UIDS and ACCEPT_GIDS if they are not provided
ACCEPT_UIDS="${ACCEPT_UIDS:-$DEFAULT_ACCEPT_UIDS}"
ACCEPT_GIDS="${ACCEPT_GIDS:-$DEFAULT_ACCEPT_GIDS}"

PORT_MAPPING="${PORT_MAPPING:-$DEFAULT_PORT_MAPPING}"

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

IFS=',' read -ra MAPPINGS <<< "$PORT_MAPPING"
for MAPPING in "${MAPPINGS[@]}"; do
    IFS=':' read -ra PORTS <<< "$MAPPING"
    TO_PORT="${PORTS[0]}"
    DEST_PORT="${PORTS[1]}"

    apply_rules "$TO_PORT" "$DEST_PORT"
done

# Ensure the rules are set
iptables -t nat -L -n -v
