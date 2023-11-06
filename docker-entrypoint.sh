#!/bin/bash

set -e

if [[ -z "$TO_PORT" ]]; then
    echo "Error: TO_PORT environment variable is not set."
    exit 1
fi

if [[ -z "$ACCEPT_UIDS" ]] && [[ -z "$ACCEPT_GIDS" ]]; then
    echo "Error: Both ACCEPT_UIDS and ACCEPT_GIDS environment variables are not set. At least one must be set."
    exit 1
fi

apply_rules() {
    local PORT_SPECIFIER="$1"

    # Apply rules for UIDs
    if [[ -n "$ACCEPT_UIDS" ]]; then
        IFS=',' read -ra UIDS <<< "$ACCEPT_UIDS"
        for USER_ID in "${UIDS[@]}"; do
            iptables -t nat -A OUTPUT -p tcp $PORT_SPECIFIER -m owner --uid-owner "$USER_ID" -j ACCEPT
        done
    fi

    # Apply rules for GIDs
    if [[ -n "$ACCEPT_GIDS" ]]; then
        IFS=',' read -ra GIDS <<< "$ACCEPT_GIDS"
        for GROUP_ID in "${GIDS[@]}"; do
            iptables -t nat -A OUTPUT -p tcp $PORT_SPECIFIER -m owner --gid-owner "$GROUP_ID" -j ACCEPT
        done
    fi

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
