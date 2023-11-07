#!/bin/bash

set -e

# Default values for ACCEPT_UIDS and ACCEPT_GIDS
DEFAULT_ACCEPT_UIDS="1010"  # Default UID of Qtap
DEFAULT_ACCEPT_GIDS="1010"  # Default GID of Qtap

DEFAULT_TO_PORT="10000" # Default listen port of Qtap

# Set default values for ACCEPT_UIDS and ACCEPT_GIDS if they are not provided
ACCEPT_UIDS="${ACCEPT_UIDS:-$DEFAULT_ACCEPT_UIDS}"
ACCEPT_GIDS="${ACCEPT_GIDS:-$DEFAULT_ACCEPT_GIDS}"

TO_PORT="${TO_PORT:-$DEFAULT_TO_PORT}"

apply_rules() {
    local PORT_SPECIFIER="$1"

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

# If DESTINATION_PORTS is set, split it into an array and apply rules for each port
if [[ -n "$DESTINATION_PORTS" ]]; then
    IFS=',' read -ra DEST_PORTS <<< "$DESTINATION_PORTS"
    for PORT in "${DEST_PORTS[@]}"; do
        apply_rules "--dport $PORT"
    done
else
    # Apply rules without specifying dport
    apply_rules ""
fi

# Ensure the rules are set
iptables -t nat -L -n -v
