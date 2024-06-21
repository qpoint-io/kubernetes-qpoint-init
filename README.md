# kubernetes-qpoint-init

A Kubernetes init container for transparently routing traffic.

## Overview

The container makes use of `iptables` and puts in place rules which selectively route traffic egressing the pod to a destination which is configurable.

The container makes use of the following concepts:

- `ACCEPT_UIDS` and `ACCEPT_GIDS`
  - Any user IDs or group IDs in these lists jump directly to the `ACCEPT` target.
- `TO_IPV4_ADDR`
  - Optional to IPv4 address which jumps to the `DNAT` target. If not provided a `REDIRECT` target is assumed.
- `TO_IPV6_ADDR`
  - Optional to IPv6 address which jumps to the `DNAT` target. If not provided a `REDIRECT` target is assumed.
- `TO_DOMAIN`
  - Optional domain which is used to perform address resolution for both IPv4 and IPv6 addresses.
- `PORT_MAPPING`
  - Optional port mapping of the form `<to_port>:<destination_port>`. The `to_port` is the port for which a jump to `DNAT` or `REDIRECT` is performed (i.e. use in `--to-destination` or `-to-port` arguments.) The `destination_port` is the port for which the `--dport` argument is set. If just `<to_port>` is provided all ports will be impacted.
- `IPV4_ACCEPT_BLOCKS`
  - Optional list of IPv4 address blocks for which a jump to `ACCEPT` should be added. This would generally include addresses such as `"127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"  # Loopback and RFC 1918 address blocks`.
- `IPV6_ACCEPT_BLOCKS`
  - Optional list of IPv6 address blocks for which a jump to `ACCEPT` should be added. This would generally include addresses such as `"::1/128,fc00::/7"  # Loopback and Unique Local Addresses (ULA)`.

A set of defaults are defined which are:

```sh
# Default values for ACCEPT_UIDS and ACCEPT_GIDS
DEFAULT_ACCEPT_UIDS="1010"  # Default UID of Qpoint
DEFAULT_ACCEPT_GIDS="1010"  # Default GID of Qpoint
DEFAULT_PORT_MAPPING="10080:80,10443:443"
DEFAULT_IPV4_ACCEPT_BLOCKS="127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"  # Loopback and RFC 1918 address blocks
DEFAULT_IPV6_ACCEPT_BLOCKS="::1/128,fc00::/7"  # Loopback and Unique Local Addresses (ULA)
```

## Usage

The rules being set can be tested in a local Docker container by running the following:

```sh
docker run \
--cap-add NET_ADMIN \
-e PORT_MAPPING="10080:80,10443:443" \
-e ACCEPT_UIDS="0,1000" \
-e ACCEPT_GIDS="0,1000" \
us-docker.pkg.dev/qpoint-edge/public/kubernetes-qpoint-init:<TAG>
```

The above will redirect destination ports within the container (or Kubernetes pod) to a local destination port. A list of UIDs and GIDs can be provided to excluded from the redirection.

This same image can be used as a Kubernetes [init container](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) with the relevant environment variables set.

See [example.yaml](example.yaml) for an example of usage within Kubernetes.
