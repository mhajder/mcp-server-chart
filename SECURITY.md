# Security Policy

## Supported versions

Only the latest chart release gets security fixes. If you can, check that the issue still happens on it before reporting.

## Reporting a vulnerability

Please do not open a public issue. Report it privately through [GitHub private vulnerability reporting](https://github.com/mhajder/mcp-server-chart/security/advisories/new).

Include the chart version, the values needed to reproduce it and what an attacker could do with it. Do not send real tokens or passwords; redact them.

I aim to acknowledge a report within 7 days and will keep you updated until it is fixed and released.

## Scope

In scope is the `mcp-server` chart, for example:

- secrets rendered into a ConfigMap, annotations, labels or `helm` output instead of a Secret
- a default that weakens the pod security settings (root user, writable root filesystem, added capabilities)
- the MCP service exposed outside the cluster without the user enabling Ingress or HTTPRoute
- a service account token or extra RBAC permissions granted to the pod by default

Vulnerabilities in an MCP server itself belong in that server's repository, and vulnerabilities in Helm or Kubernetes belong with those projects.
