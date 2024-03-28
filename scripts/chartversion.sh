#!/bin/bash
TAG=${GITHUB_REF#refs/tags/v}

cat > helm/designate-certmanager-webhook/Chart.yaml <<EOF
apiVersion: v1
appVersion: "1.0.0"
description: ACME webhook Implementation for OpenStack Designate
name: designate-certmanager-webhook
version: "${TAG}"
EOF