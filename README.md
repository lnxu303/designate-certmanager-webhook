<p align="center">
  <img src="./images/cert-manager-designate.svg" height="256" width="256" alt="designate-certmanager-webhook project logo" />
</p>

<p align="center">
<a href="https://github.com/Fred78290/designate-certmanager-webhook/actions/workflows/ci.yaml">
  <img alt="Build Status" src="https://github.com/Fred78290/designate-certmanager-webhook/actions/workflows/ci.yaml/badge.svg?branch=master">
</a>
<a href="https://sonarcloud.io/dashboard?id=Fred78290_designate-certmanager-webhook">
  <img alt="Quality Gate Status" src="https://sonarcloud.io/api/project_badges/measure?project=Fred78290_designate-certmanager-webhook&metric=alert_status">
</a>
<a href="https://github.com/Fred78290/designate-certmanager-webhook/blob/master/LICENSE">
  <img alt="Licence" src="https://img.shields.io/hexpm/l/plug.svg">
</a>
</p>

# ACME webhook Implementation for OpenStack Designate

This is an ACME webhook implementation for the [cert-manager](http://docs.cert-manager.io). It works with OpenStack Designate DNSaaS to generate certificates using DNS-01 challenges.

It's a rewrite of code [designate-certmanager-webhook](https://github.com/syseleven/designate-certmanager-webhook) with test integration and helm chart.

## Installation

```bash
helm repo add designate-certmanager https://fred78290.github.io/designate-certmanager-webhook/
helm repo update
````

## Prerequisites

To use this chart [Helm](https://helm.sh/) must be installed in your Kubernetes cluster. Setting up Kubernetes and Helm and is outside the scope of this README. Please refer to the Kubernetes and Helm documentation. You will also need the [cert-manager](https://github.com/cert-manager/cert-manager). Please refer to the cert-manager [documentation](https://docs.cert-manager.io) for full technical documentation for the project. This README assumes, the cert-manager is installed in the namespace `cert-manager`. Adapt examples accordingly, if you have installed it in a different namespace.

## Deployment

***Optional*** You can choose to pre-create your authentication secret or configure the values via helm. If you don\'t want to configure your credentials via helm, create a kubernetes secret in the cert-manager namespace containing your OpenStack credentials and the project ID with the DNS zone you would like to use:

### OpenStack Application Credentials

/etc/openstack/clouds.yaml or ~/.config/openstak/clouds.yaml is also supported

### Secret with OpenStack User Credentials

```bash
kubectl --namespace cert-manager create secret generic cloud-credentials \
  --from-literal=OS_AUTH_URL=${OS_AUTH_URL} \
  --from-literal=OS_DOMAIN_NAME=${OS_DOMAIN_NAME} \
  --from-literal=OS_REGION_NAME=${OS_REGION_NAME}> \
  --from-literal=OS_PROJECT_ID=${OS_PROJECT_ID} \
  --from-literal=OS_PROJECT_NAME=${OS_PROJECT_NAME} \
  --from-literal=OS_USERNAME=${OS_USERNAME} \
  --from-literal=OS_PASSWORD=${OS_PASSWORD}
```

### Secret with OpenStack Application Credentials

```bash
kubectl --namespace cert-manager create secret generic cloud-credentials \
  --from-literal=OS_AUTH_URL=${OS_AUTH_URL} \
  --from-literal=OS_DOMAIN_NAME=${OS_DOMAIN_NAME} \
  --from-literal=OS_REGION_NAME=${OS_REGION_NAME} \
  --from-literal=OS_APPLICATION_CREDENTIAL_ID=${OS_APPLICATION_CREDENTIAL_ID} \
  --from-literal=OS_APPLICATION_CREDENTIAL_NAME=${OS_APPLICATION_CREDENTIAL_NAME} \
  --from-literal=OS_APPLICATION_CREDENTIAL_SECRET=${OS_APPLICATION_CREDENTIAL_SECRET}
```

### Chart deployment

You can install the helm chart with the command:

```bash
helm install --name designate-certmanager --namespace=cert-manager designate-certmanager-webhook
helm upgrade -i designate-certmanager designate-certmanager-webhook/designate-certmanager \
    --set groupName=acme.mycompany.com \
    --set image.tag=v0.1.0 \
    --set image.pullPolicy=Always \
    --set openstack.username="${OS_USERNAME}" \
    --set openstack.password="${OS_PASSWORD}" \
    --set openstack.application_credential_id="${OS_APPLICATION_CREDENTIAL_ID}" \
    --set openstack.application_credential_secret="${OS_APPLICATION_CREDENTIAL_NAME}" \
    --set openstack.project_id="${OS_PROJECT_ID}" \
    --set openstack.project_name="${OS_PROJECT_NAME}" \
    --set openstack.region_name="${OS_REGION_NAME}" \
    --set openstack.auth_url="${OS_AUTH_URL}" \
    --set openstack.domain_name="${OS_DOMAIN_NAME}" \
    --namespace cert-manager

```

## Configuration

To configure your Issuer or ClusterIssuer to use this webhook as a DNS-01 solver use the following reference for a ClusterIssuer template. To use this in production please replace the reference to the Letsencrypt staging api accordingly:

```
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    # You must replace this email address with your own.
    # Let's Encrypt will use this to contact you about expiring
    # certificates, and issues related to your account.
    email: user@example.com
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      # Secret resource used to store the account's private key.
      name: example-issuer-account-key
    # Add the designate dns webhook for dns challenges
    solvers:
    - dns01:
        webhook:
          config:
            verify: false
            ttl: 600
          groupName: acme.mycompany.com
          solverName: designateDNS
```

You are now ready to create you first certificate resource. The easiest way to accomplish this is to add an annotation to an Ingress rule. Please adapt this example for your own needs:

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging
  name: myingress
spec:
  ingressClassName: nginx
  rules:
  - host: my.ingress.com
    http:
      paths:
      - backend:
          service:
            name: myservice
            port:
              number: 1234
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - my.ingress.com
    secretName: myingress-cert
```

## Development

### Running the test suite

All DNS providers **must** run the DNS01 provider conformance testing suite,
else they will have undetermined behaviour when used with cert-manager.

**It is essential that you configure and run the test suite when creating a
DNS01 webhook.**

An example Go test file has been provided in [main_test.go]().

> Prepare

```bash
$ scripts/fetch-test-binaries.sh
```

You can run the test suite with:

```bash
$ scripts/test.sh
```

The example file has a number of areas you must fill in and replace with your
own options in order for tests to pass.
