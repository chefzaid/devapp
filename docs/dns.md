# Public DNS

This repository owns `devapp.swirlit.dev`, including DNS, Kubernetes Ingress routing
and application redirects. The platform supplies the shared zone, TLS,
ingress and optional HA Tunnel; its installer does not create or remove these
application DNS records.

## Direct ingress

In Cloudflare DNS, create or update a **proxied A** record for each hostname
above with the public ingress IPv4. Obtain the address from the platform operator
or the ingress Service:

```sh
kubectl get service traefik -n infra \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

## HA ingress

After the platform's HA activation succeeds, switch each owned hostname to a
**proxied CNAME** with target `<publishedTunnelID>.cfargotunnel.com`. Verify the
published checkpoint belongs to this zone before changing DNS:

```sh
kubectl get configmap bm-cluster-public-ingress -n infra -o json | \
  jq -er '.data | select(.mode == "tunnel" and .domain == "swirlit.dev" and
    .publishedTunnelID != null and .publishedTunnelID != "" and
    .publishedTunnelID == .tunnelID) | .publishedTunnelID + ".cfargotunnel.com"'
```

No output or a nonzero exit means the target is not ready. Do not infer readiness
from a prepared Tunnel ID or keep pointing at the original host after the direct
listener is retired. The platform's zone-wide Tunnel routes preserve the request
hostname; the application-owned Ingress selects the backend. No application name
needs adding to the platform repository.

Review conflicting A/AAAA/CNAME records for these exact hostnames before changing
their address target. Preserve unrelated records, especially MX and TXT records.
[Cloudflare Tunnel DNS routing](https://developers.cloudflare.com/tunnel/routing/)
describes the CNAME target. Verify the public URL and application health after
DNS changes, then perform the application HA checks in the deployment guide.

## Repository helper

With an authenticated Kubernetes context and a Cloudflare token supplied through
`CLOUDFLARE_API_TOKEN`, run:

```sh
./infra/scripts/configure-cloudflare.sh
```

The helper reads the platform ingress checkpoint and selects direct A or published
Tunnel CNAME routing. It refuses unpublished or mismatched Tunnel state,
conflicting address records, and a direct-IP override while HA is selected.
Re-run it during this application's DNS cutover after platform activation.
