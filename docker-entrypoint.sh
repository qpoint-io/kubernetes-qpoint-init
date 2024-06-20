#!/bin/bash

set -e

# Function to resolve domain to IPv4
resolve_domain_to_ipv4() {
    local domain=$1
    local ip

    # If there are multiple addresses returned, the first address is selected
    ip=$(dig +short A "$domain" | head -n 1)
    if [[ -z "$ip" ]]; then
        echo "Error: Failed to resolve domain $domain"
        exit 1
    fi

    echo "$ip"
}

# Function to resolve domain to IPv6
resolve_domain_to_ipv6() {
    local domain=$1
    local ip

    # If there are multiple addresses returned, the first address is selected
    ip=$(dig +short AAAA "$domain" | head -n 1)
    if [[ -z "$ip" ]]; then
        echo "Error: Failed to resolve domain $domain"
        exit 1
    fi

    echo "$ip"
}

# If provided, resolve TO_DOMAIN to IP and set it to TO_IPV4_ADDR and TO_IPV6_ADDR
if [[ -n "$TO_DOMAIN" ]]; then
    TO_IPV4_ADDR=$(resolve_domain_to_ipv4 "$TO_DOMAIN")
    TO_IPV6_ADDR=$(resolve_domain_to_ipv6 "$TO_DOMAIN")
fi

# Default values for ACCEPT_UIDS and ACCEPT_GIDS
DEFAULT_ACCEPT_UIDS="1010"  # Default UID of Qpoint
DEFAULT_ACCEPT_GIDS="1010"  # Default GID of Qpoint
DEFAULT_PORT_MAPPING="10080:80,10443:443"
DEFAULT_IPV4_ACCEPT_BLOCKS="127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"  # Loopback and RFC 1918 address blocks
DEFAULT_IPV6_ACCEPT_BLOCKS="::1/128,fc00::/7"  # Loopback and Unique Local Addresses (ULA)

# Set default values if they are not provided
ACCEPT_UIDS="${ACCEPT_UIDS:-$DEFAULT_ACCEPT_UIDS}"
ACCEPT_GIDS="${ACCEPT_GIDS:-$DEFAULT_ACCEPT_GIDS}"
PORT_MAPPING="${PORT_MAPPING:-$DEFAULT_PORT_MAPPING}"
IPV4_ACCEPT_BLOCKS="${ACCEPT_BLOCKS:-$DEFAULT_IPV4_ACCEPT_BLOCKS}"
IPV6_ACCEPT_BLOCKS="${ACCEPT_BLOCKS:-$DEFAULT_IPV6_ACCEPT_BLOCKS}"

echo "----->"
echo "ACCEPT_UIDS: $ACCEPT_UIDS"
echo "ACCEPT_GIDS: $ACCEPT_GIDS"
echo "PORT_MAPPING: $PORT_MAPPING"
echo "IPV4_ACCEPT_BLOCKS: $IPV4_ACCEPT_BLOCKS"
echo "IPV6_ACCEPT_BLOCKS: $IPV6_ACCEPT_BLOCKS"
echo "<-----"

apply_rules() {
    local TO_PORT="$1"
    local DEST_PORT="$2"
    local iptables_cmd="$3"
    local TO_ADDR="$4"

    local PORT_SPECIFIER=""
    if [[ -n "$DEST_PORT" ]]; then
        PORT_SPECIFIER="--dport $DEST_PORT"
    fi

    # Apply rules for UIDs
    IFS=',' read -ra UIDS <<< "$ACCEPT_UIDS"
    for USER_ID in "${UIDS[@]}"; do
        $iptables_cmd -t nat -A OUTPUT -p tcp $PORT_SPECIFIER -m owner --uid-owner "$USER_ID" -j ACCEPT
    done

    # Apply rules for GIDs
    IFS=',' read -ra GIDS <<< "$ACCEPT_GIDS"
    for GROUP_ID in "${GIDS[@]}"; do
        $iptables_cmd -t nat -A OUTPUT -p tcp $PORT_SPECIFIER -m owner --gid-owner "$GROUP_ID" -j ACCEPT
    done

    # Apply redirect or DNAT rule
    if [[ -n "$TO_ADDR" ]]; then
        $iptables_cmd -t nat -A OUTPUT -p tcp $PORT_SPECIFIER -j DNAT --to-destination "$TO_ADDR:$TO_PORT"
    else
        $iptables_cmd -t nat -A OUTPUT -p tcp $PORT_SPECIFIER -j REDIRECT --to-port "$TO_PORT"
    fi
}

# Apply IPv4 rules for each block
IFS=',' read -ra BLOCKS <<< "$IPV4_ACCEPT_BLOCKS"
for BLOCK in "${BLOCKS[@]}"; do
    iptables -t nat -A OUTPUT -p tcp -d "$BLOCK" -j ACCEPT
done

# Apply IPv6 rules for each block
IFS=',' read -ra BLOCKS <<< "$IPV6_ACCEPT_BLOCKS"
for BLOCK in "${BLOCKS[@]}"; do
    ip6tables -t nat -A OUTPUT -p tcp -d "$BLOCK" -j ACCEPT
done

IFS=',' read -ra MAPPINGS <<< "$PORT_MAPPING"
for MAPPING in "${MAPPINGS[@]}"; do
    IFS=':' read -ra PORTS <<< "$MAPPING"
    TO_PORT="${PORTS[0]}"
    DEST_PORT="${PORTS[1]}"

    apply_rules "$TO_PORT" "$DEST_PORT" "iptables" "$TO_IPV4_ADDR"
    apply_rules "$TO_PORT" "$DEST_PORT" "ip6tables" "$TO_IPV6_ADDR"
done

# Ensure the rules are set
iptables -t nat -L -n -v
ip6tables -t nat -L -n -v
