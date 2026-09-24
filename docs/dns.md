# Public DNS

One central platform serves separate `int`, `uat` and `prod` application clusters.
DevApp owns each environment's exact hostname, Ingress routes and browser-client
redirects. The platform owns cluster registration, the managed Cloudflare zone,
certificate preparation and private connectivity.

## Direct ingress

The central `infra/deployment-environments` ConfigMap records each environment's
`domain`, `ingressAddress` and TLS Secret. Onboarding uses the app label from
`infra/environments/<env>/settings.json` to reconcile the selected proxied A, AAAA or CNAME record:

| Environment | Example hostname | Destination |
|---|---|---|
| `int` | `devapp.int.example.com` | Integration cluster ingress address. |
| `uat` | `devapp.uat.example.com` | Acceptance cluster ingress address. |
| `prod` | `devapp.example.com` | Production cluster ingress address. |

`appSubdomain: "@"` selects the environment domain itself. It does not select
the parent Cloudflare zone apex. Production cannot claim the reserved `int` or
`uat` domain or their descendants.

Use central [onboarding](deployment.md#add-or-reconfigure-this-repository) to
reconcile the configured hosts. Confirm the target in the central inventory;
do not discover an application address from the central platform's Traefik
Service. The generated environment Ingress must use the same hostname and TLS
Secret as its registered target.

## Certificates and changes

The Cloudflare token needs Zone Read, DNS Edit, and SSL and Certificates Edit
for the managed parent zone. The certificate permission covers Origin CA issuance
and [certificate coverage inspection](https://developers.cloudflare.com/api/resources/ssl/subresources/certificate_packs/methods/list/).
The parent zone's Universal SSL wildcard does not cover those deeper hostnames;
pre-issue Advanced/Custom edge coverage before publication. Existing Total TLS
coverage can be reused; enabling Total TLS alone needs DNS first and cannot pass
the first-publication guard. See the platform's
[Cloudflare guide](https://github.com/chefzaid/bm-cluster/blob/main/docs/networking.md#cloudflare).

Review conflicting A/AAAA/CNAME records for the exact hostname and preserve
unrelated MX/TXT records. Changing the app hostname does not automatically delete
its old record. Verify the replacement route, runtime configuration and both
API health routes before retiring the old hostname:

```sh
curl --fail https://devapp.int.example.com/runtime-config.json
curl --fail https://devapp.int.example.com/health/user
curl --fail https://devapp.int.example.com/health/order
```

## HA ingress

The environment's registered ingress address must reach its available application
nodes before enabling the [HA workload profile](deployment.md#future-multi-node-ha-profile).
The central platform's own Cloudflare Tunnel is not an application-cluster target.
A separately designed environment Tunnel or load balancer needs its own routing
and certificate validation; no central Tunnel checkpoint is reused implicitly.

## Central reconciliation

Rerun the platform's `add-repos.sh` to reconcile DevApp's declared hosts against
registered environment targets. Keep DNS and browser-client changes together;
deployment verifies that the selected public route serves its expected runtime
identity configuration.
