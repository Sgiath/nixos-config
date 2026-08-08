# Pangolin as an ingress for Vesta

**Research date:** 2026-08-08  
**Pangolin version context:** 1.21.1, released 2026-07-30  
**Question:** Can Pangolin replace Vesta's Nginx setup, including public hosting of `sgiath.dev`, or should they work together?

## Recommendation

Do **not** remove Nginx as the first step.

If you want Pangolin's identity-aware access and tunnel management, the best initial architecture is:

```text
Internet / Cloudflare
        |
        v
Pangolin's Traefik ingress on Vesta :80/:443
        |
        +-- public, auth-bypassed resources
        |      `-- Nginx on an internal port
        |              `-- sgiath.dev and its existing custom behavior
        |
        +-- Pangolin-authenticated resources
        |      `-- selected dashboards and administrative services
        |
        `-- direct protocol ports remain separate
               `-- XMPP, TURN, LiveKit media, SSH, DNS, and similar traffic
```

This is a **coexistence** design, not a clean Nginx replacement. Pangolin does not serve static files itself, and its documented self-hosted ingress is Traefik. Keeping Nginx behind Traefik preserves the substantial site-specific behavior already implemented for `sgiath.dev` while allowing Pangolin to protect selected applications.

However, Pangolin adds limited value to the public, unauthenticated `sgiath.dev` page itself. If the main objective is only to simplify public web hosting, the current Nginx setup is simpler. Pangolin becomes compelling when the objective includes one or more of:

- putting SSO or policy-based access in front of private dashboards;
- exposing services from other machines without inbound port forwarding;
- replacing a conventional VPN with identity-aware resource access;
- managing several sites or networks through Newt tunnels;
- centralizing access rules across public and private resources.

The recommended decision is therefore:

1. **Keep Nginx for `sgiath.dev` and specialized HTTP behavior.**
2. **Trial Pangolin for a small set of private or administrative services.**
3. If the trial succeeds, let Pangolin/Traefik become the public `:80/:443` ingress and move Nginx to an internal listener.
4. Only remove Nginx after each custom route has been deliberately migrated to another backend or Traefik middleware and tested.

## Short answers

| Question | Answer |
|---|---|
| Can Pangolin publish an ordinary public website? | Yes. Create a public HTTP/HTTPS resource and add a rule that bypasses Pangolin authentication. |
| Can it use the apex `sgiath.dev` domain? | Yes. Pangolin documents root/apex domains as supported resources. |
| Does Pangolin serve the static files? | No. It routes to an HTTP target, such as Nginx or another static-file server. |
| Can Pangolin fully replace Nginx today? | Not without recreating Nginx's static serving, rewrites, content negotiation, generated responses, access controls, and certificate sharing elsewhere. |
| Can Pangolin and Nginx work together? | Yes. The well-supported shape is Pangolin/Traefik in front and Nginx behind it. |
| Can both independently listen on Vesta's same IP ports 80 and 443? | No. One edge proxy must own each address and port. The standard Pangolin deployment assigns both ports to Traefik. |
| Can Nginx remain in front of Pangolin? | It may be technically possible with custom ports, but Pangolin does not document this as its standard architecture. It creates more integration risk than putting Nginx behind Pangolin. |
| Is Gerbil required? | No. Pangolin has a local-only mode without Gerbil. Gerbil and Newt are useful when services are reached through tunnels. |
| Is Traefik required? | It is the ingress used by the documented self-hosted architecture, including the mode without Gerbil. |
| Is Community Edition enough? | Yes for this trial: public HTTP resources, local targets, authentication/bypass rules, tunnels, and optionally raw TCP/UDP. Some HA, wildcard, and identity features are edition-dependent. |

## What Nginx currently does on Vesta

Vesta enables Nginx globally in `modules/nixos/server/nginx.nix`. It is responsible for much more than forwarding a few hostnames:

- TLS termination and Cloudflare DNS-based ACME issuance;
- HTTP/2 and HTTP/3/QUIC-related configuration;
- compression and proxy defaults;
- large request bodies, with a global maximum of 2048 MiB;
- static-file serving;
- redirects, generated JSON responses, CORS headers, and custom error handling;
- WebSocket proxying;
- LAN-only access rules for selected services;
- certificates that are also consumed directly by Prosody and coturn.

The Vesta host currently enables these Nginx-backed services:

| Hostname | Current role | Important behavior |
|---|---|---|
| `sgiath.dev` | Public static site and protocol-discovery host | Static files, redirects, custom 404, download autoindex, Link headers, HTML/Markdown content negotiation, Matrix and Nostr well-known routes, Matrix API proxy path |
| `sinai.camp` | Static download host and redirect | Download autoindex; root redirects to another website |
| `5e.sgiath.dev` | Static D&D tools | Static Nix store content and a Foundry-specific CORS header |
| `audio.sgiath.dev` | Audiobookshelf | HTTP and WebSockets to localhost |
| `ai.sgiath.dev` | Buzz relay | WebSockets, media uploads up to 600 MiB, one-hour proxy timeouts |
| `foundry.sgiath.dev` | Foundry VTT | WebSockets and special interception/rewrite of `/game` authentication redirects |
| `matrix.sgiath.dev` | Continuwuity Matrix homeserver | Matrix API and WebSocket-capable proxying |
| `matrix-rtc.sgiath.dev` | LiveKit and token service | Path-based split between two upstream ports, including WebSockets |
| `turn.sgiath.dev` | Certificate host for coturn | Nginx obtains the certificate; TURN itself uses separate direct ports |
| `mollysocket.sgiath.dev` | MollySocket | HTTP and WebSockets |
| `nas.sgiath.dev` | NAS proxy | HTTP and WebSockets to another LAN machine |
| `niamh.sgiath.dev` | Hermes webhooks/UI | Path-based upstream split; the UI is restricted to localhost/LAN |
| `nostr.sgiath.dev` | Nostr relay | WebSockets |
| `ntfy.sgiath.dev` | ntfy | HTTP and WebSockets |
| `search.sgiath.dev` | SearXNG | HTTP proxy to localhost |
| `torrent.sgiath.dev` | Transmission/Flood | Authentication at the application and WebSockets |
| `watch.sgiath.dev` | Jellyfin | HTTP and WebSockets |
| `dns.sgiath` | Pi-hole LAN UI | Private name, redirect to `/admin/`, explicit LAN address allow/deny rules, and rejected TLS |

Monitoring is presently disabled, but its module adds another Grafana/WebSocket proxy and a static GoAccess path when enabled.

### `sgiath.dev` is not a basic static vhost

The apex site is the main reason not to attempt an immediate Nginx removal. Its current Nginx configuration includes:

- `Accept: text/markdown` content negotiation for the same extensionless URLs that normally return HTML;
- `Vary: Accept` response handling;
- explicit Markdown media types;
- injected Link headers from generated configuration files;
- `/ping` returning a generated plain-text response;
- redirects for social and source-code aliases;
- CORS and cross-origin headers under `/profile`;
- special canonicalization for `/presentations`;
- directory listing and ZIP/file fallbacks under `/download`;
- Matrix server, client, and support discovery documents;
- a Matrix API path forwarded to Continuwuity;
- a Nostr identity document under `/.well-known/nostr.json`.

Pangolin's job is to route and authorize a request. It does not replace these origin-server behaviors. A complete Nginx removal would still require a static server or application that implements them, or custom Traefik configuration outside Pangolin's normal resource model.

### Nginx also owns certificates used by non-HTTP services

Prosody reads `/var/lib/acme/sgiath.dev/fullchain.pem` and its private key directly. Coturn does the same for the `turn.sgiath.dev` certificate. Their certificate renewal hooks reload Nginx and restart the respective service.

If Traefik takes over ACME, its default certificate store is `acme.json`, not the PEM paths these services expect. Removing Nginx therefore also requires an explicit certificate plan, such as:

- keep NixOS ACME certificate issuance independently of Nginx;
- deploy a supported certificate extraction/synchronization mechanism from Traefik;
- or issue separate certificates specifically for Prosody and coturn.

This is a migration dependency, not a cosmetic configuration change.

### Several important ports are outside HTTP ingress

Pangolin replacing HTTP ingress would not automatically replace Vesta's direct protocol exposure. Matrix calling and federation-related components use TURN and LiveKit media ports outside Nginx. XMPP uses its native client/server protocols. Pi-hole exposes TCP and UDP DNS. SSH uses a dedicated public port.

Pangolin supports raw TCP and UDP resources, but those resources do not get HTTP hostnames, TLS certificates, Pangolin authentication, or HTTP access rules. Moving latency-sensitive or federation protocols through raw resources would need separate compatibility and performance testing. There is no need to include them in an initial HTTP migration.

## What Pangolin provides

Pangolin is a control and access platform around several components:

- **Pangolin** provides the dashboard, API, authentication, authorization, and orchestration.
- **Traefik** is the public reverse proxy and TLS termination layer.
- **Badger** integrates Pangolin's authorization with Traefik.
- **Gerbil** manages and relays the server side of WireGuard tunnels.
- **Newt** runs near a target network and connects it to Pangolin.

The documented public HTTP path is broadly:

```text
Internet -> Traefik -> Badger authorization -> local target or tunnel -> backend
```

For local resources on Vesta, Pangolin can run without Gerbil. Traefik then reaches targets over the local network. This is the simplest mode for evaluating Pangolin on the existing server.

For services on the NAS, desktops, or another remote network, Newt and Gerbil avoid opening inbound ports on the target network. That is where Pangolin provides a capability the current Nginx setup does not have by itself.

## Public hosting of `sgiath.dev`

### Supported aspects

Pangolin supports all of the basic ingress requirements:

- an HTTP/HTTPS public resource;
- a root/apex domain such as `sgiath.dev`;
- a local or tunneled HTTP target;
- automatic TLS through Traefik and Let's Encrypt;
- public access through a bypass-auth rule;
- multiple targets and health checks if the site is replicated later.

The standard public-site configuration would conceptually be:

```text
Resource: sgiath.dev
Type: public HTTP/HTTPS
Target: http://nginx-internal:<port>
Access rule: bypass authentication for all site requests
```

Pangolin authentication is enabled for public HTTP resources by default. The bypass rule is essential for a normal public website, crawlers, feeds, protocol discovery, and non-browser clients.

### What must remain at the target

The target must still implement:

- static-file reads from `/data/www/sgiath.dev`;
- HTML/Markdown negotiation;
- redirects and custom responses;
- Matrix and Nostr well-known content;
- Matrix path proxying;
- CORS, Link, and content-type headers;
- autoindex and fallback rules.

Keeping Nginx as that target is the smallest safe change. Replacing it with Caddy, another static server, or a custom application is possible, but that is an independent origin-server migration rather than something Pangolin accomplishes.

### Cloudflare considerations

The live `sgiath.dev` site is currently proxied by Cloudflare. Pangolin has a first-party Cloudflare proxy guide, including trusted proxy/client-IP and WebSocket considerations. Cloudflare can remain in front of a self-hosted Pangolin deployment, but the Pangolin configuration must trust the proxy correctly and the applicable Cloudflare settings must preserve its dashboard/API WebSockets.

Ordinary self-hosted Pangolin domains can point directly at the ingress IP. DNS provider access is only required for DNS-01 issuance, such as wildcard certificates. Pangolin Cloud offers delegated and CNAME-based domain models, but delegating the entire `sgiath.dev` apex would also move authority for unrelated MX, TXT, and service records. That is unnecessary and high-risk for this setup.

## Architecture options

### Option 1: Keep the current Nginx setup

```text
Cloudflare -> Nginx -> services
```

**Advantages**

- lowest complexity and fewest moving parts;
- already supports all current paths and protocols;
- static files are served directly;
- existing NixOS ACME integration supplies Prosody and coturn;
- no extra control-plane database, middleware, or tunnel components;
- no migration risk for the public site.

**Disadvantages**

- no central SSO/policy layer for dashboards;
- remote services require direct network reachability or another VPN/tunnel solution;
- access control remains distributed between Nginx and applications;
- no Pangolin client/private-resource experience.

**Best when:** the goal is only reliable public hosting and basic reverse proxying.

### Option 2: Pangolin/Traefik in front, Nginx behind

```text
Cloudflare -> Pangolin/Traefik :443 -> Nginx internal listener -> services/files
```

**Advantages**

- preserves existing Nginx behavior;
- permits gradual, hostname-by-hostname migration;
- Pangolin can protect selected resources with SSO or access rules;
- public sites can bypass authentication;
- Newt can later connect services on other networks;
- the change is reversible if Nginx remains a normal internal origin.

**Disadvantages**

- adds another reverse-proxy hop;
- adds Pangolin, Traefik, Badger, a database/control plane, and potentially Gerbil;
- Traefik must own public ports 80 and 443, so Nginx listeners must move;
- forwarding of client IP, scheme, host, WebSockets, large bodies, and long timeouts must be verified through both layers;
- Pangolin becomes an additional single point of failure;
- certificate sharing with Prosody and coturn needs redesign.

**Best when:** you want Pangolin's access controls and tunnels but cannot justify rewriting the existing origins.

This is the recommended trial and migration architecture.

### Option 3: Replace Nginx completely

```text
Cloudflare -> Pangolin/Traefik -> individual services and a new static-site origin
```

**Advantages**

- one fewer proxy layer after migration;
- all HTTP resources are represented directly in Pangolin/Traefik;
- centralized access policies.

**Disadvantages**

- Pangolin still does not serve the static site;
- `sgiath.dev` needs a new origin implementation;
- specialized Nginx rewrites, generated responses, ACLs, timeout/body-size overrides, and path routing must move elsewhere;
- certificate consumers outside HTTP need a replacement workflow;
- Pangolin's resource UI is not a general replacement for every Nginx directive;
- greater cutover and rollback risk.

**Best when:** there is a separate desire to redesign the origin-server layer, not merely to adopt Pangolin.

This is not recommended as the starting point.

### Option 4: Put Pangolin on a small VPS and tunnel back to Vesta

```text
Cloudflare/DNS -> Pangolin VPS -> Newt tunnel -> Nginx/services on Vesta
```

**Advantages**

- removes the home public IP and inbound HTTP forwarding from the origin architecture;
- Pangolin can front services even if Vesta later moves behind restrictive NAT;
- separates public ingress from the home server;
- Nginx can remain unchanged as the origin.

**Disadvantages**

- all public traffic gains a VPS and tunnel hop;
- the VPS becomes another failure and security boundary;
- bandwidth-heavy Jellyfin, Audiobookshelf, Foundry, downloads, Matrix, and media services may be expensive or slower;
- TURN, LiveKit media, XMPP, DNS, and other direct protocols need separate handling;
- a single VPS still does not provide high availability.

**Best when:** hiding the home origin and avoiding inbound network exposure are more important than minimum latency and complexity.

## Fit by Vesta use case

| Use case | Pangolin fit | Recommendation |
|---|---|---|
| Public `sgiath.dev` site | Supported, but little benefit when auth is bypassed | Keep Nginx as its origin; optionally route through Pangolin later |
| Static `5e.sgiath.dev` | Straightforward public resource | Can migrate after validating CORS and caching |
| `sinai.camp` downloads | Supported via Nginx target | Keep Nginx unless autoindex/download behavior is rebuilt elsewhere |
| SearXNG | Good HTTP target | Candidate for either public bypass or Pangolin authentication |
| Transmission/Flood | Strong candidate | Protect with Pangolin auth after checking application/API clients |
| NAS UI | Strong candidate | Prefer Pangolin authentication or private access; Newt can connect the NAS network if useful |
| Hermes UI | Strong candidate | Existing LAN ACL suggests it is intended to be private; Pangolin is a better policy surface than source-IP rules |
| Grafana, if re-enabled | Strong candidate | Dashboard authentication is a core Pangolin use case |
| Audiobookshelf/Jellyfin | Technically suitable, but bandwidth-sensitive | Test streaming, range requests, client applications, and Cloudflare/Pangolin limits before migration |
| Foundry VTT | Suitable with testing | Validate WebSockets, long sessions, redirects, upload sizes, and client IP forwarding |
| Buzz relay | Suitable with careful tuning | Validate WebSockets, 600 MiB uploads, and one-hour proxy timeouts through Traefik/Pangolin |
| Matrix homeserver | Higher risk | Test federation, well-known paths, request sizes, client IPs, and WebSockets; do not use as the first migration |
| Matrix RTC/LiveKit | Mixed HTTP and direct media | The token/API hostname may use Pangolin; keep media ports direct initially |
| Nostr relay | Likely suitable | Validate long-lived WebSockets and forwarded client IP |
| ntfy/MollySocket | Likely suitable | Validate mobile clients, long polling/WebSockets, and public API behavior before adding authentication |
| Pi-hole DNS/UI | UI can be proxied; DNS is separate | Keep DNS direct on LAN; private Pangolin access could replace the UI's LAN ACL |
| XMPP/Prosody | Native protocol plus shared certificate | Keep direct initially; solve certificate issuance before any Nginx removal |
| TURN/coturn | Raw UDP/TCP/TLS and shared certificate | Keep direct; tunneling adds little and may harm real-time traffic |

## Security and reliability tradeoffs

### Improvements Pangolin can bring

- Per-resource authentication and policy instead of relying only on application logins or LAN source addresses.
- Outbound Newt connections can reduce inbound exposure on target networks.
- Central management of users, roles, share links, and resource rules.
- Health checks and multiple targets for backend failover.
- A unified private-access client and NAT traversal model.

### New risks and operational costs

- The standard stack has more components and state than Nginx alone.
- Gerbil receives `NET_ADMIN` and `SYS_MODULE` capabilities in the official Compose example.
- More secrets must be protected, including Pangolin server and site credentials.
- Traefik, Badger, Pangolin, Newt, and Gerbil versions must be upgraded compatibly.
- A default self-hosted deployment is a single node. If Pangolin or Traefik fails, every resource routed through it fails even if Nginx and the applications are healthy.
- Enterprise clustering exists, but it also requires shared services, multiple instances, DNS/failover infrastructure, and an operator-provided load balancer.
- Pangolin collects anonymous usage telemetry by default; its documentation provides a setting to disable this.

For a single home server, Pangolin should be adopted because its access/tunnel capabilities are wanted, not because it is expected to be a simpler reverse proxy.

## Suggested proof of concept

Avoid making `sgiath.dev`, Matrix, TURN, or XMPP the first test.

1. Deploy Pangolin Community Edition in local-only mode, without Gerbil initially.
2. Give Traefik temporary test ports or a separate test address so the current Nginx ingress stays untouched during evaluation.
3. Add a disposable test hostname and verify public access with a bypass-auth rule.
4. Add one private candidate, preferably the Pi-hole UI, Transmission UI, NAS UI, or a re-enabled Grafana instance.
5. Verify browser login, logout, session expiry, direct API behavior, mobile clients if applicable, forwarded client IPs, and service logs.
6. Test WebSockets and a large upload against a non-critical service.
7. Back up Pangolin state and perform an upgrade using pinned versions.
8. Simulate Pangolin/Traefik downtime and confirm that rollback to Nginx is understood.
9. Decide whether Pangolin's access experience justifies making Traefik the production edge.

If it does, plan the production migration in separate stages:

1. certificate strategy for Prosody and coturn;
2. internal Nginx listener and trusted-proxy configuration;
3. public, auth-bypassed `sgiath.dev` resource;
4. simple HTTP applications;
5. WebSocket and large-upload applications;
6. Matrix HTTP endpoints;
7. only then consider whether any Nginx origin behavior should be rewritten and removed.

## Acceptance checks for a production cutover

At minimum, verify these through the public hostname after each relevant migration:

- `sgiath.dev` returns HTML normally and Markdown for `Accept: text/markdown`.
- The apex site retains all Link headers, `Vary`, redirects, custom media types, and CORS headers.
- Matrix and Nostr well-known documents return exact JSON and expected CORS headers.
- Matrix federation and clients operate from outside the LAN.
- WebSocket services remain connected through normal idle periods.
- Foundry redirect behavior is unchanged.
- Buzz accepts its intended upload size and long-running requests.
- Jellyfin and Audiobookshelf support seeking/range requests and their native clients.
- ntfy and MollySocket clients work without an interactive Pangolin login unless explicitly redesigned.
- Source-IP ACLs are replaced with intentional Pangolin rules, not accidentally removed.
- Prosody and coturn certificates renew and reload successfully.
- Direct TURN, LiveKit media, XMPP, SSH, and DNS paths remain reachable where intended.
- The original client IP and scheme are correctly visible to applications and logs.
- A tested rollback can restore Nginx as the edge without waiting for DNS propagation.

## Final conclusion

Pangolin supports public hosting of `sgiath.dev`, including the apex domain and unauthenticated access. It does so by putting Traefik in front of an HTTP target. It does **not** replace the origin-server functions currently implemented by Nginx.

For Vesta, a full replacement would be a broad ingress and origin redesign with meaningful risk around static-site behavior, Matrix discovery, WebSockets, large uploads, LAN ACLs, and shared ACME certificates. There is no strong reason to take that risk merely to host the public page through Pangolin.

Pangolin and Nginx can work well together. The sensible path is to use Pangolin for what it adds: identity-aware access, policy, and tunnels. Keep Nginx behind it for `sgiath.dev` and other specialized virtual hosts. After a successful trial, simple proxy-only hosts can move directly to Pangolin targets, while Nginx remains a focused origin for the routes that genuinely need it.

## Primary sources

### Pangolin documentation

- [System Architecture](https://docs.pangolin.net/development/system-architecture)
- [Docker Compose installation](https://docs.pangolin.net/self-host/manual/docker-compose)
- [DNS & Networking](https://docs.pangolin.net/self-host/dns-and-networking)
- [Run without tunneling](https://docs.pangolin.net/self-host/advanced/without-tunneling)
- [Cloudflare Proxy](https://docs.pangolin.net/self-host/advanced/cloudflare-proxy)
- [Domains](https://docs.pangolin.net/manage/domains)
- [Public HTTP/HTTPS resources](https://docs.pangolin.net/manage/resources/public/http-https)
- [Resource targets](https://docs.pangolin.net/manage/resources/public/targets)
- [Public resource authentication](https://docs.pangolin.net/manage/resources/public/authentication)
- [Access-control rules](https://docs.pangolin.net/manage/access-control/rules)
- [Forwarded identity headers](https://docs.pangolin.net/manage/access-control/forwarded-headers)
- [Raw TCP/UDP resources](https://docs.pangolin.net/manage/resources/public/raw-resources)
- [Health checks and failover](https://docs.pangolin.net/manage/resources/public/healthchecks-failover)
- [NAT traversal](https://docs.pangolin.net/manage/clients/nat-traversal)
- [Wildcard domains and DNS-01](https://docs.pangolin.net/self-host/advanced/wild-card-domains)
- [Wildcard resources](https://docs.pangolin.net/manage/resources/public/wildcard-resources)
- [Clustering](https://docs.pangolin.net/self-host/advanced/clustering)
- [Enterprise Edition](https://docs.pangolin.net/self-host/enterprise-edition)
- [Telemetry](https://docs.pangolin.net/self-host/telemetry)
- [Update procedure](https://docs.pangolin.net/self-host/how-to-update)

### Official projects and releases

- [Pangolin repository](https://github.com/fosrl/pangolin)
- [Pangolin 1.21.1 release](https://github.com/fosrl/pangolin/releases/tag/1.21.1)
- [Newt repository](https://github.com/fosrl/newt)
- [Gerbil repository](https://github.com/fosrl/gerbil)
- [Official Pangolin pricing and edition comparison](https://pangolin.net/pricing)

### Repository evidence used for the Vesta inventory

- `systems/x86_64-linux/vesta/default.nix`
- `modules/nixos/server/nginx.nix`
- `modules/nixos/server/sgiath.nix`
- `modules/nixos/server/matrix.nix`
- `modules/nixos/server/xmpp.nix`
- all active service modules imported by `modules/nixos/server/default.nix`
