{{- define "demo-django.env" }}
- name: POSTGRES_HOST
  value: {{ .Values.postgres.host | quote }}
- name: POSTGRES_PORT
  value: {{ .Values.postgres.port | quote }}
- name: POSTGRES_DB
  value: {{ .Values.postgres.database | quote }}
- name: POSTGRES_USER
  value: {{ .Values.postgres.username | quote }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgres.existingSecret | quote }}
      key: {{ .Values.postgres.passwordKey | quote }}
- name: REDIS_URL
  value: {{ .Values.redis.url | quote }}
{{- end }}