{{/*
common.deployment renders a Deployment from standard values keys:
  app.{name,version}, replicaCount, image.*, service.targetPort,
  env, resources, healthCheck.*, nodeSelector, tolerations, affinity
Consumed by app charts via: {{ include "common.deployment" . }}
*/}}
{{- define "common.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.app.name }}
  labels:
    app: {{ .Values.app.name }}
    version: {{ .Values.app.version }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Values.app.name }}
  template:
    metadata:
      labels:
        app: {{ .Values.app.name }}
        version: {{ .Values.app.version }}
    spec:
      containers:
      - name: {{ .Values.app.name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - containerPort: {{ .Values.service.targetPort }}
          name: http
        env:
          {{- toYaml .Values.env | nindent 10 }}
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
        {{- if .Values.healthCheck.enabled }}
        livenessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: {{ .Values.healthCheck.initialDelaySeconds }}
          periodSeconds: {{ .Values.healthCheck.periodSeconds }}
          timeoutSeconds: {{ .Values.healthCheck.timeoutSeconds }}
          failureThreshold: {{ .Values.healthCheck.failureThreshold }}
        readinessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: {{ .Values.healthCheck.initialDelaySeconds }}
          periodSeconds: {{ .Values.healthCheck.periodSeconds }}
          timeoutSeconds: {{ .Values.healthCheck.timeoutSeconds }}
          failureThreshold: {{ .Values.healthCheck.failureThreshold }}
        {{- end }}
      {{- if .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml .Values.nodeSelector | nindent 8 }}
      {{- end }}
      {{- if .Values.tolerations }}
      tolerations:
        {{- toYaml .Values.tolerations | nindent 8 }}
      {{- end }}
      {{- if .Values.affinity }}
      affinity:
        {{- toYaml .Values.affinity | nindent 8 }}
      {{- end }}
{{- end -}}
