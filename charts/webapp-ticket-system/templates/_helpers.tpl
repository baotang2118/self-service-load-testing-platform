{{- define "webapp-ticket-system.fullname" -}}
{{- default .Release.Name .Values.fullnameOverride | trunc 40 | trimSuffix "-" -}}
{{- end -}}

{{- define "webapp-ticket-system.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "webapp-ticket-system.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{ include "webapp-ticket-system.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "webapp-ticket-system.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}

{{- define "webapp-ticket-system.imagePullSecrets" -}}
{{- with .Values.image.pullSecrets }}
imagePullSecrets:
{{ toYaml . | indent 2 }}
{{- end }}
{{- end -}}

{{- define "webapp-ticket-system.env" -}}
{{- $name := include "webapp-ticket-system.fullname" . -}}
{{- $allowedHosts := .Values.django.allowedHosts -}}
{{- $allowedHosts = append $allowedHosts (printf "%s-web" $name) -}}
{{- if .Values.ingress.enabled -}}
{{- range .Values.ingress.hosts -}}
{{- $allowedHosts = append $allowedHosts .host -}}
{{- end -}}
{{- end -}}
- name: POSTGRES_DB
  value: {{ .Values.database.name | quote }}
- name: POSTGRES_USER
  value: {{ .Values.database.user | quote }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ required "database.passwordSecret.name is required" .Values.database.passwordSecret.name | quote }}
      key: {{ required "database.passwordSecret.key is required" .Values.database.passwordSecret.key | quote }}
- name: POSTGRES_HOST
  value: {{ .Values.database.host | quote }}
- name: POSTGRES_PORT
  value: {{ .Values.database.port | quote }}
- name: PGSSLMODE
  value: {{ .Values.database.sslmode | quote }}
- name: DJANGO_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ required "django.secretKeySecret.name is required" .Values.django.secretKeySecret.name | quote }}
      key: {{ required "django.secretKeySecret.key is required" .Values.django.secretKeySecret.key | quote }}
- name: DJANGO_DEBUG
  value: {{ ternary "1" "0" .Values.django.debug | quote }}
- name: DJANGO_ALLOWED_HOSTS
  value: {{ join "," (uniq $allowedHosts) | quote }}
{{- end -}}
