{{- define "mcp-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resource name. Defaults to the release name so `helm install librenms-mcp ...`
produces resources named librenms-mcp rather than librenms-mcp-mcp-server.
*/}}
{{- define "mcp-server.fullname" -}}
{{- default .Release.Name .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "mcp-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "mcp-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mcp-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "mcp-server.labels" -}}
helm.sh/chart: {{ include "mcp-server.chart" . }}
{{ include "mcp-server.selectorLabels" . }}
app.kubernetes.io/version: {{ include "mcp-server.imageVersion" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: mcp-server
{{- end }}

{{- define "mcp-server.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mcp-server.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "mcp-server.image" -}}
{{- $repo := required "image.repository is required (e.g. ghcr.io/mhajder/librenms-mcp)" .Values.image.repository }}
{{- if .Values.image.digest }}
{{- printf "%s@%s" $repo .Values.image.digest }}
{{- else }}
{{- printf "%s:%s" $repo (include "mcp-server.scalar" (required "image.tag or image.digest is required" .Values.image.tag)) }}
{{- end }}
{{- end }}

{{/*
helm test image: repository[:tag][@digest].
*/}}
{{- define "mcp-server.testImage" -}}
{{- $img := .Values.tests.image }}
{{- $ref := required "tests.image.repository is required" $img.repository }}
{{- with $img.tag }}{{ $ref = printf "%s:%s" $ref (include "mcp-server.scalar" .) }}{{ end }}
{{- with $img.digest }}{{ $ref = printf "%s@%s" $ref . }}{{ end }}
{{- $ref }}
{{- end }}

{{/*
Version label value: the tag, or a short digest when only a digest is set.
*/}}
{{- define "mcp-server.imageVersion" -}}
{{- if .Values.image.tag }}
{{- /* Label values must start and end with [A-Za-z0-9]; tags may start with _ or end in . after trunc. */}}
{{- $tag := include "mcp-server.scalar" .Values.image.tag | replace "+" "_" | trunc 63 }}
{{- regexReplaceAll "^[^A-Za-z0-9]+|[^A-Za-z0-9]+$" $tag "" }}
{{- else }}
{{- .Values.image.digest | replace "sha256:" "" | trunc 12 }}
{{- end }}
{{- end }}

{{/*
Values scalar as a string. toJson keeps the digits of float64 numbers,
which toString would turn into 2.0240101e+07.
*/}}
{{- define "mcp-server.scalar" -}}
{{- if kindIs "float64" . }}{{ toJson . }}{{ else }}{{ toString . }}{{ end -}}
{{- end }}

{{/*
Validate the bearer token inputs and return the one source the chart sets,
or "" (it may still come from existingSecret / envFrom).
*/}}
{{- define "mcp-server.bearerTokenSource" -}}
{{- if hasKey (.Values.env | default dict) "MCP_HTTP_BEARER_TOKEN" }}
{{- fail "MCP_HTTP_BEARER_TOKEN must not be in env: that renders it into a plain ConfigMap. Use mcp.bearerToken.existingSecret, existingSecret or secretEnv." }}
{{- end }}
{{- $sources := list }}
{{- if .Values.mcp.bearerToken.value }}{{ $sources = append $sources "mcp.bearerToken.value" }}{{ end }}
{{- if .Values.mcp.bearerToken.existingSecret }}{{ $sources = append $sources "mcp.bearerToken.existingSecret" }}{{ end }}
{{- /* An empty secretEnv / extraEnv entry still renders and overrides other
tokens, so it counts as a source. */}}
{{- $empty := list }}
{{- $secretEnv := .Values.secretEnv | default dict }}
{{- if hasKey $secretEnv "MCP_HTTP_BEARER_TOKEN" }}
{{- $sources = append $sources "secretEnv.MCP_HTTP_BEARER_TOKEN" }}
{{- if not (get $secretEnv "MCP_HTTP_BEARER_TOKEN") }}{{ $empty = append $empty "secretEnv.MCP_HTTP_BEARER_TOKEN" }}{{ end }}
{{- end }}
{{- range .Values.extraEnv }}
{{- if eq .name "MCP_HTTP_BEARER_TOKEN" }}
{{- $sources = append $sources "extraEnv" }}
{{- if not (or .value .valueFrom) }}{{ $empty = append $empty "extraEnv" }}{{ end }}
{{- end }}
{{- end }}
{{- if gt (len $sources) 1 }}
{{- fail (printf "Set the MCP bearer token in one place only, got: %s" (join ", " $sources)) }}
{{- end }}
{{- if and $empty (or .Values.existingSecret .Values.envFrom) }}
{{- fail (printf "MCP_HTTP_BEARER_TOKEN is empty in %s, which overrides any token from existingSecret / envFrom and disables auth. Remove the empty entry." (first $empty)) }}
{{- end }}
{{- if and $sources (not $empty) }}{{ first $sources }}{{ end }}
{{- end }}

{{- define "mcp-server.createSecret" -}}
{{- if or .Values.secretEnv .Values.mcp.bearerToken.value }}true{{- end }}
{{- end }}

{{/*
Deployment strategy: the user's, or Recreate when a ReadWriteOnce volume is
mounted (a RollingUpdate pod on another node would hang on Multi-Attach).
*/}}
{{- define "mcp-server.strategy" -}}
{{- if .Values.strategy }}
{{- toYaml .Values.strategy }}
{{- else if and .Values.persistence.enabled (or (has "ReadWriteOnce" .Values.persistence.accessModes) (has "ReadWriteOncePod" .Values.persistence.accessModes)) -}}
type: Recreate
{{- end }}
{{- end }}

{{- define "mcp-server.pvcName" -}}
{{- default (include "mcp-server.fullname" .) .Values.persistence.existingClaim }}
{{- end }}
