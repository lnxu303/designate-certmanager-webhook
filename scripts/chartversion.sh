#!/bin/bash
TAG=${GITHUB_REF#refs/tags/v}

cat > helm/designate-certmanager-webhook/Chart.yaml <<EOF
apiVersion: v2
appVersion: "${TAG}"
description: A Helm chart to install designate-certmanager-webhook
name: designate-certmanager
version: "${TAG}"
home: https://github.com/Fred78290/designate-certmanager-webhook/
icon: https://raw.githubusercontent.com/Fred78290/designate-certmanager-webhook/master/images/cert-manager-webhook.png
keywords:
  - cert-manager
  - designate
  - openstack
  - dns-saas
maintainers:
  - name: Fred78290
    url: https://github.com/Fred78290/
sources:
  - https://github.com/Fred78290/designate-certmanager-webhook/
EOF