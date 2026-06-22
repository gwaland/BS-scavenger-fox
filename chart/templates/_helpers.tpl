{{/*
Expand the name of the chart.
*/}}
{{- define "scavenger-fox.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "scavenger-fox.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart name and version.
*/}}
{{- define "scavenger-fox.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "scavenger-fox.labels" -}}
helm.sh/chart: {{ include "scavenger-fox.chart" . }}
{{ include "scavenger-fox.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "scavenger-fox.selectorLabels" -}}
app.kubernetes.io/name: {{ include "scavenger-fox.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name.
*/}}
{{- define "scavenger-fox.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "scavenger-fox.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "scavenger-fox.database.secretName" -}}
{{- required "database.existingSecret must be set" .Values.database.existingSecret -}}
{{- end }}

{{- define "scavenger-fox.database.urlKey" -}}
{{- required "database.urlKey must be set" .Values.database.urlKey -}}
{{- end }}

{{- define "scavenger-fox.appSecrets.secretName" -}}
{{- required "secrets.existingSecret must be set" .Values.secrets.existingSecret -}}
{{- end }}

{{- define "scavenger-fox.appSecrets.photoReviewTokenKey" -}}
{{- required "secrets.photoReviewTokenKey must be set" .Values.secrets.photoReviewTokenKey -}}
{{- end }}

{{- define "scavenger-fox.appSecrets.adminApiTokenKey" -}}
{{- required "secrets.adminApiTokenKey must be set" .Values.secrets.adminApiTokenKey -}}
{{- end }}

{{- define "scavenger-fox.assets.pvcName" -}}
{{- printf "%s-assets" (include "scavenger-fox.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
