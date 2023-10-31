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

if [[ -z "$ACCEPT_UID" ]] && [[ -z "$ACCEPT_GID" ]]; then
    echo "Error: Both ACCEPT_UID and ACCEPT_GID environment variables are not set. At least one must be set."
    exit 1
fi

# Split the list of ports from DESTINATION_PORTS into an array
IFS=',' read -ra DEST_PORTS <<< "$DESTINATION_PORTS"

# Loop through each port in the array
for PORT in "${DEST_PORTS[@]}"; do
    # If ACCEPT_UID is set, then loop through each UID
    if [[ -n "$ACCEPT_UID" ]]; then
        IFS=',' read -ra UIDS <<< "$ACCEPT_UID"
        for UID in "${UIDS[@]}"; do
            iptables -t nat -A OUTPUT -p tcp --dport "$PORT" -m owner --uid-owner "$UID" -j ACCEPT
        done
    fi

    # If ACCEPT_GID is set, then loop through each GID
    if [[ -n "$ACCEPT_GID" ]]; then
        IFS=',' read -ra GIDS <<< "$ACCEPT_GID"
        for GID in "${GIDS[@]}"; do
            iptables -t nat -A OUTPUT -p tcp --dport "$PORT" -m owner --gid-owner "$GID" -j ACCEPT
        done
    fi

    # Redirect rule for each port
    iptables -t nat -A OUTPUT -p tcp --dport "$PORT" -j REDIRECT --to-port "$TO_PORT"
done

# Ensure the rules are set
iptables -t nat -L -n -v
