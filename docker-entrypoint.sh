#!/bin/bash

set -e

# Check for required environment variables
if [[ -z "$DESTINATION_PORTS" ]]; then
    echo "Error: DESTINATION_PORTS environment variable is not set."
    exit 1
fi

if [[ -z "$TO_PORT" ]]; then
    echo "Error: TO_PORT environment variable is not set."
    exit 1
fi

if [[ -z "$ACCEPT_UIDS" ]] && [[ -z "$ACCEPT_GIDS" ]]; then
    echo "Error: Both ACCEPT_UIDS and ACCEPT_GIDS environment variables are not set. At least one must be set."
    exit 1
fi

# Split the list of ports from DESTINATION_PORTS into an array
IFS=',' read -ra DEST_PORTS <<< "$DESTINATION_PORTS"

# Loop through each port in the array
for PORT in "${DEST_PORTS[@]}"; do
    # If ACCEPT_UIDS is set, then loop through each UID
    if [[ -n "$ACCEPT_UIDS" ]]; then
        IFS=',' read -ra UIDS <<< "$ACCEPT_UIDS"
        for USER_ID in "${UIDS[@]}"; do
            iptables -t nat -A OUTPUT -p tcp --dport "$PORT" -m owner --uid-owner "$USER_ID" -j ACCEPT
        done
    fi

    # If ACCEPT_GIDS is set, then loop through each GID
    if [[ -n "$ACCEPT_GIDS" ]]; then
        IFS=',' read -ra GIDS <<< "$ACCEPT_GIDS"
        for GROUP_ID in "${GIDS[@]}"; do
            iptables -t nat -A OUTPUT -p tcp --dport "$PORT" -m owner --gid-owner "$GROUP_ID" -j ACCEPT
        done
    fi
done

# Now process the redirect rules for each port
for PORT in "${DEST_PORTS[@]}"; do
    # If TO_ADDR is set, use DNAT to redirect to a new IP and port
    if [[ -n "$TO_ADDR" ]]; then
        iptables -t nat -A OUTPUT -p tcp --dport "$PORT" -j DNAT --to-destination "$TO_ADDR:$TO_PORT"
    else
        iptables -t nat -A OUTPUT -p tcp --dport "$PORT" -j REDIRECT --to-port "$TO_PORT"
    fi
done

# Ensure the rules are set
iptables -t nat -L -n -v
