# Contributing

Thanks for helping out. Bug reports and feature requests go through the [issue templates](https://github.com/mhajder/mcp-server-chart/issues/new/choose). For security problems, follow [SECURITY.md](SECURITY.md) instead.

## Development setup

You need [Helm](https://helm.sh/docs/intro/install/) 3.8+ and [prek](https://github.com/j178/prek).

```sh
git clone https://github.com/mhajder/mcp-server-chart.git
cd mcp-server-chart
prek install
```

`prek install` sets up the git hooks, which check YAML and whitespace, run `helm lint` on commit and check the commit message.

## Before opening a pull request

```sh
# Lint with every optional resource enabled
helm lint --strict charts/mcp-server -f charts/mcp-server/ci/full-values.yaml

# Render every example and look at the output
for f in examples/*.yaml; do helm template test charts/mcp-server -f "$f" > /dev/null || echo "FAILED: $f"; done

# Optional: validate against the Kubernetes schemas
# (the second schema location covers the HTTPRoute CRD, as in CI)
helm template test charts/mcp-server -f charts/mcp-server/ci/full-values.yaml | kubeconform -strict -summary \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
```

- Add every new value to `values.yaml` with a `# --` comment and a `# @section --` line
  (one of the existing sections; untagged values end up under "Other Values"), and to
  `values.schema.json`.
- Turn on new optional resources in `charts/mcp-server/ci/full-values.yaml` so CI renders them.
- Add a [helm-unittest](https://github.com/helm-unittest/helm-unittest) case in `charts/mcp-server/tests/`
  for new template logic, validation (`fail`) or NOTES warnings.
- Keep the defaults secure: non-root, read-only root filesystem, no capabilities.
- Update the README when you add an option, an example or change behavior.
- Do not edit `charts/mcp-server/README.md`: the `helm-docs` pre-commit hook generates
  it from `README.md.gotmpl` and the `# --` comments in `values.yaml`.
- Do not bump `version` in `Chart.yaml`; the release PR does that.

## Adding a server example

1. Copy `examples/librenms-mcp.yaml` to `examples/<name>.yaml`.
2. Put plain settings under `env` and list every secret key in the `kubectl create secret` comment at the top.
3. Add the server to the table in the README.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/), for example `feat(chart): add networkPolicy` or `fix(httproute): render timeouts`. The changelog and the next chart version are generated from them.

## License

By contributing, you agree that your contributions are licensed under the project's MIT license.
