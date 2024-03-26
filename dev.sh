#!/bin/bash

helm install designate-certmanager-webhook \
    --set groupName=aldune.private \
    --set image.repository=devregistry.aldunelabs.com/designate-certmanager-webhook \
    --set image.tag=0.1.0 \
    --set image.pullPolicy=Always \
    --namespace cert-manager ./helm/designate-certmanager-webhook $@
