# kubernetes-qtap-init

A Kubernetes init container for transparently routing traffic.

## Usage

The rules being set can be tested in a local Docker container by running the following:

```sh
docker run \
--cap-add NET_ADMIN \
-e DESTINATION_PORTS="443,80,8080" \
-e TO_PORT="10000" \
-e ACCEPT_UIDS="0,1000" \
-e ACCEPT_GIDS="0,1000" \
us-docker.pkg.dev/qpoint-edge/public/kubernetes-qtap-init:<TAG>
```

The above will redirect destination ports within the container (or Kubernetes pod) to a local destination port. A list of UIDs and GIDs can be provided to excluded from the redirection.

This same image can be used as a Kubernetes [init container](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) with the relevant environment variables set.

See (example.yaml) for an example of usage within Kubernetes.
