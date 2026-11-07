<div align="center">

# MCP Server Helm Chart

**One generic Helm chart to run any HTTP-transport Model Context Protocol server on Kubernetes**

[![License](https://img.shields.io/github/license/mhajder/mcp-server-chart)](https://github.com/mhajder/mcp-server-chart/blob/main/LICENSE)
[![Helm](https://img.shields.io/badge/helm-v3%20%7C%20v4-0F1689?logo=helm&logoColor=white)](https://helm.sh/)
[![Kubernetes](https://img.shields.io/badge/tested%20on%20k8s-1.35%20%7C%201.36%20%7C%201.37-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![OCI](https://img.shields.io/badge/ghcr.io-charts%2Fmcp--server-2496ED?logo=docker&logoColor=white)](https://github.com/mhajder/mcp-server-chart/pkgs/container/charts%2Fmcp-server)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/mcp-server)](https://artifacthub.io/packages/search?repo=mcp-server)

[![Lint and Validate](https://github.com/mhajder/mcp-server-chart/actions/workflows/lint.yml/badge.svg)](https://github.com/mhajder/mcp-server-chart/actions/workflows/lint.yml)
[![Pre-commit Checks](https://github.com/mhajder/mcp-server-chart/actions/workflows/pre-commit.yml/badge.svg)](https://github.com/mhajder/mcp-server-chart/actions/workflows/pre-commit.yml)

[Installation](#-installation) · [Supported Servers](#-supported-servers) · [Configuration](#-configuration) · [Security](#-security-defaults)

</div>

The `mcp-server` chart deploys any of my MCP servers (LibreNMS, NetBox, Zabbix, ...)
with the same templates. Every server is one Helm release of this chart with its
own values file, so probes, security settings and ingress fixes land everywhere at once.

## ✨ Features

### Deployment

- One chart for every server: set `image.repository` and the server's env vars
- Resources named after the release (`librenms-mcp`, not `librenms-mcp-mcp-server`)
- Ready-to-use values file per server in [`examples/`](examples/)
- Automatic pod restart when the chart-managed ConfigMap or Secret changes (checksum annotations).
  After rotating an `existingSecret`, run `kubectl rollout restart` (the install notes print the command)

### Networking

- `ClusterIP` Service on port `8000`, MCP endpoint at `/mcp`
- Optional **Ingress** or **Gateway API HTTPRoute**
- Session affinity switch for running more than one replica (plus HTTPRoute `sessionPersistence` passthrough)
- Optional **NetworkPolicy** limiting who can reach the MCP port, and optionally outgoing traffic

### Configuration & Secrets

- Plain settings in `env` (ConfigMap), credentials from an existing Secret
- MCP bearer token from a Secret or a value
- Escape hatches: `extraEnv`, `envFrom`, `extraVolumes`, `extraVolumeMounts`
- Values validated by a JSON schema before anything is rendered

### Operations

- Startup, liveness and readiness probes on `GET /health`
- Optional persistent volume, PodDisruptionBudget, private registry pull secrets
- `helm test` checks the health endpoint through the Service
- Releases signed with cosign and shipped with build provenance ([verify](#verifying-the-chart))

## 🚀 Installation

### Prerequisites

- Kubernetes 1.23 or newer (CI validates manifests for 1.23 and 1.35–1.37, and installs on 1.35–1.37)
- Helm 3.8+ (OCI registry support) or Helm 4 (CI lints with 3.8, the newest 3.x and 4)
- Credentials for the system the MCP server talks to (e.g. a LibreNMS API token)

### Quick Install

```sh
# 1. Namespace and credentials (upstream API token + MCP bearer token)
kubectl create namespace mcp
kubectl -n mcp create secret generic librenms-mcp-credentials \
  --from-literal=LIBRENMS_TOKEN='your-librenms-token' \
  --from-literal=MCP_HTTP_BEARER_TOKEN="$(openssl rand -hex 32)"

# 2. Get the example values and set LIBRENMS_URL
curl -fsSLO https://raw.githubusercontent.com/mhajder/mcp-server-chart/main/examples/librenms-mcp.yaml

# 3. Install
helm upgrade --install librenms-mcp oci://ghcr.io/mhajder/charts/mcp-server \
  -n mcp -f librenms-mcp.yaml
```

The MCP endpoint inside the cluster is `http://librenms-mcp.mcp.svc:8000/mcp`.

### Verify

```sh
# Health endpoint (no token needed)
kubectl -n mcp port-forward svc/librenms-mcp 8000 &
curl http://127.0.0.1:8000/health

# Built-in Helm test
helm test librenms-mcp -n mcp
```

### Expose Outside the Cluster

With Gateway API:

```yaml
httpRoute:
  enabled: true
  parentRefs:
    - name: shared-gateway
      namespace: gateway-system
  hostnames:
    - librenms-mcp.example.com
```

Or with an Ingress controller:

```yaml
ingress:
  enabled: true
  className: traefik
  hosts:
    - host: librenms-mcp.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: librenms-mcp-tls
      hosts:
        - librenms-mcp.example.com
```

### Connect an MCP Client

```sh
# Claude Code
claude mcp add --transport http librenms https://librenms-mcp.example.com/mcp \
  --header "Authorization: Bearer <MCP_HTTP_BEARER_TOKEN>"
```

## 📦 Supported Servers

Each file in [`examples/`](examples/) starts with the exact `kubectl create secret`
command for that server.

| Server | What it connects to | Example values | Image |
|---|---|---|---|
| [librenms-mcp](https://github.com/mhajder/librenms-mcp) | LibreNMS network monitoring | [`librenms-mcp.yaml`](examples/librenms-mcp.yaml) | `ghcr.io/mhajder/librenms-mcp` |
| [netbox-mcp](https://github.com/mhajder/netbox-mcp) | NetBox DCIM/IPAM | [`netbox-mcp.yaml`](examples/netbox-mcp.yaml) | `ghcr.io/mhajder/netbox-mcp` |
| [zabbix-mcp](https://github.com/mhajder/zabbix-mcp) | Zabbix monitoring | [`zabbix-mcp.yaml`](examples/zabbix-mcp.yaml) | `ghcr.io/mhajder/zabbix-mcp` |
| [oxidized-mcp](https://github.com/mhajder/oxidized-mcp) | Oxidized config backups | [`oxidized-mcp.yaml`](examples/oxidized-mcp.yaml) | `ghcr.io/mhajder/oxidized-mcp` |
| [glpi-mcp](https://github.com/mhajder/glpi-mcp) | GLPI IT asset management | [`glpi-mcp.yaml`](examples/glpi-mcp.yaml) | `ghcr.io/mhajder/glpi-mcp` |
| [ghostfolio-mcp](https://github.com/mhajder/ghostfolio-mcp) | Ghostfolio wealth management | [`ghostfolio-mcp.yaml`](examples/ghostfolio-mcp.yaml) | `ghcr.io/mhajder/ghostfolio-mcp` |

The chart works with any MCP server image that serves HTTP on a port and answers
`GET /health`. For other images, adjust `mcp.port` and the probes.

## 🔧 Configuration

### Values

Every value with its default and description is listed in
[`charts/mcp-server/README.md`](charts/mcp-server/README.md). That file is generated
from the `# --` comments in [`values.yaml`](charts/mcp-server/values.yaml) and is also
shown by `helm show readme oci://ghcr.io/mhajder/charts/mcp-server`.

### Environment Variable Precedence

Later sources win:

```text
env (ConfigMap) → existingSecret → secretEnv → envFrom → chart-set MCP_* vars → extraEnv
```

An `extraEnv` entry with the same name as a chart-set `MCP_*` var replaces it.
Set `MCP_HTTP_BEARER_TOKEN` in one place only; the chart fails if two of
`mcp.bearerToken.*`, `secretEnv` and `extraEnv` set it, and when an empty
`secretEnv` / `extraEnv` entry would override a token from `existingSecret` or `envFrom`.

### Running More Than One Replica

MCP sessions live in pod memory, so every request of a session must reach the same pod:

- Clients talking to the Service directly: `service.sessionAffinity: ClientIP`.
- Through an Ingress: use the controller's sticky sessions, e.g. for ingress-nginx
  `nginx.ingress.kubernetes.io/affinity: cookie` plus
  `nginx.ingress.kubernetes.io/affinity-mode: persistent` (the default `balanced`
  mode moves some sessions to new pods on scale-up). Then set `ingress.stickySessions: true`
  to silence the install warning. `sessionAffinity` does not apply,
  because Ingress controllers send traffic straight to the pods.
- Through a Gateway: add `sessionPersistence` to `httpRoute.rules` (needs a Gateway
  implementation that supports it, and the Gateway API experimental-channel CRDs:
  standard-channel CRDs drop the field).

### Network Policy

The servers hold credentials for NetBox, Zabbix, GLPI and others, so it is worth
limiting who can call them. Your CNI must enforce NetworkPolicy (Calico, Cilium,
k3s, ...). Kubelet probes come from the node and are normally not affected.

```yaml
networkPolicy:
  enabled: true
  ingressFrom:              # default: pods in the release namespace only
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
  egress:
    enabled: true           # DNS to kube-dns stays allowed
    rules:
      - to:
          - ipBlock:
              cidr: 10.20.30.40/32   # the NetBox / Zabbix / GLPI API
        ports:
          - port: 443
            protocol: TCP
```

With egress restricted, also allow the OIDC identity provider when OAuth login
is enabled. Clusters with NodeLocal DNSCache need `networkPolicy.egress.dnsTo`
pointing at it (e.g. `ipBlock: {cidr: 169.254.20.10/32}`).

### Server-Specific Notes

**OAuth login (`ghostfolio-mcp`, `glpi-mcp`).** With OIDC (`OIDC_CONFIG_URL`,
`OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`, `OIDC_BASE_URL`) or GLPI login
(`GLPI_OAUTH_LOGIN=true`), FastMCP stores client registrations and tokens in
`FASTMCP_HOME`, which the images set to `/data`. The root filesystem is read-only,
so mount a volume there:

```yaml
persistence:
  enabled: true # mountPath defaults to /data
replicaCount: 1 # each pod keeps its own registrations
```

Run 1 replica: registrations are not shared between pods, and a ReadWriteOnce
volume cannot be mounted on two nodes. Set `OIDC_BASE_URL` / `GLPI_OAUTH_BASE_URL`
to the public URL (the Ingress or HTTPRoute host), and keep the default `/` path so
the OAuth routes outside `/mcp` (e.g. `/.well-known/*`, `/auth/callback`) are reachable.

**Per-user tokens (`netbox-mcp`, `glpi-mcp`).** With `NETBOX_TOKEN_PASSTHROUGH=true` or
`GLPI_TOKEN_PASSTHROUGH=true`, each client sends its own NetBox / GLPI token, so
`MCP_HTTP_BEARER_TOKEN` is not needed.

The install notes detect these modes only from `env`. Settings kept in
`existingSecret` or `secretEnv` still work, but the notes cannot see them.

### Custom CA Bundle Example

```yaml
extraVolumes:
  - name: corporate-ca
    configMap:
      name: corporate-ca
extraVolumeMounts:
  - name: corporate-ca
    mountPath: /etc/ssl/corporate
    readOnly: true
extraEnv:
  - name: SSL_CERT_FILE
    value: /etc/ssl/corporate/ca.crt
```

## 🔒 Security Defaults

| Setting | Value |
|---|---|
| User / group | `10001:10001` (matches the images), `runAsNonRoot: true` |
| Root filesystem | Read-only; `/tmp` is an `emptyDir` |
| Capabilities | All dropped, no privilege escalation |
| Seccomp | `RuntimeDefault` |
| Service account token | Not mounted (MCP servers don't use the Kubernetes API) |
| Health probes | `GET /health`, needs no bearer token and does not call the upstream system |

> [!WARNING]
> Without `MCP_HTTP_BEARER_TOKEN`, anyone who can reach the Service can call every
> tool. The install notes print a warning when no token is configured.

> [!TIP]
> All examples set `READ_ONLY_MODE=true`. Remove it only when you want AI agents
> to make changes.

### Verifying the Chart

Every release is signed with [cosign](https://github.com/sigstore/cosign) (keyless,
by the release workflow) and has a GitHub build provenance attestation. Check either
before installing:

```sh
cosign verify ghcr.io/mhajder/charts/mcp-server:<version> \
  --certificate-identity https://github.com/mhajder/mcp-server-chart/.github/workflows/release-please.yml@refs/heads/main \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

gh attestation verify oci://ghcr.io/mhajder/charts/mcp-server:<version> \
  --repo mhajder/mcp-server-chart
```

## 🔄 Updating Servers

The examples use `image.tag: latest` with `pullPolicy: Always`. `helm upgrade` does
not restart pods when only the image behind `latest` changed, so pull the new build with:

```sh
kubectl -n mcp rollout restart deployment/librenms-mcp
```

> [!IMPORTANT]
> `latest` is built from every push to `main`, not from releases. For production,
> pin a released version, e.g. `--set image.tag=1.13.0`.

## 🛠️ Development

```sh
# Lint with every optional resource enabled
helm lint --strict charts/mcp-server -f charts/mcp-server/ci/full-values.yaml

# Render an example
helm template librenms-mcp charts/mcp-server -f examples/librenms-mcp.yaml

# Unit tests (charts/mcp-server/tests/). Install the plugin once; Helm 4 needs
# --verify=false because plugins installed from git are not signed.
helm plugin install https://github.com/helm-unittest/helm-unittest --version v1.2.1 --verify=false
helm unittest charts/mcp-server

# Run the pre-commit hooks (includes the unit tests)
prek run --all-files
```

On macOS the plugin installer can fail at "Validating Checksum": it calls `sha256sum`
with GNU-only flags. Run the tests in Docker instead:
`docker run --rm -v "$PWD/charts":/apps helmunittest/helm-unittest:4.3.0-1.2.1@sha256:28ea86c3e0b07f501f0c2e9c08b9f41e240f4a4b571cb5106b36cf0f0607e989 mcp-server`.

CI ([`lint.yml`](.github/workflows/lint.yml)) runs `helm lint`, the unit tests and
kubeconform on every `ci/*.yaml` and `examples/*.yaml`, then installs `librenms-mcp` on
a kind cluster and runs `helm test`.

## 📦 Releasing

Use conventional commits on `main` (`feat:`, `fix:`, ...). release-please keeps a
release PR open that bumps `charts/mcp-server/Chart.yaml`. Merging it tags
`vX.Y.Z` and pushes the chart to `oci://ghcr.io/mhajder/charts/mcp-server`.

For [Artifact Hub](https://artifacthub.io/), the release turns the version's
conventional commits (the ones that touch the chart, as in `CHANGELOG.md`) into the
`artifacthub.io/changes` annotation of the packaged chart. The
repository metadata lives in [`artifacthub-repo.yml`](artifacthub-repo.yml); the
`Artifact Hub Metadata` workflow pushes it to the OCI repository when it changes.

## 🤝 Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the dev setup, checks and commit message format, and use the [issue templates](https://github.com/mhajder/mcp-server-chart/issues/new/choose) for bugs and feature requests.

Found a security problem? Please report it privately as described in [SECURITY.md](SECURITY.md).

## 📜 License

MIT License - see [LICENSE](LICENSE) for details.
