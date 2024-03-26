#!/bin/bash
set -o pipefail -o nounset

CURDIR=$(dirname $0)

GOOS=$(go env GOOS)
GOARCH=$(go env GOARCH)
KUBE_VERSION=1.29.3

pushd $CURDIR/../

export TEST_ASSET_ETCD=_test/kubebuilder/bin/etcd
export TEST_ASSET_KUBE_APISERVER=_test/kubebuilder/bin/kube-apiserver
export TEST_ASSET_KUBECTL=_test/kubebuilder/bin/kubectl
export TEST_MANIFEST_PATH=_test/kubebuilder/designate
export TEST_ZONE_NAME=aldune.private
export TEST_DNS_SERVER=10.0.0.5:53

mkdir -p $TEST_MANIFEST_PATH

curl -fsSL https://go.kubebuilder.io/test-tools/${KUBE_VERSION}/${GOOS}/${GOARCH} -o kubebuilder-tools.tar.gz

mkdir -p _test/kubebuilder

pushd _test
tar -xvf ../kubebuilder-tools.tar.gz
popd

rm kubebuilder-tools.tar.gz

OSENV=(
	"OS_AUTH_URL"
	"OS_USERNAME"
	"OS_USERID"
	"OS_PASSWORD"
	"OS_PASSCODE"
	"OS_TENANT_ID"
	"OS_TENANT_NAME"
	"OS_DOMAIN_ID"
	"OS_DOMAIN_NAME"
	"OS_APPLICATION_CREDENTIAL_ID"
	"OS_APPLICATION_CREDENTIAL_NAME"
	"OS_APPLICATION_CREDENTIAL_SECRET"
	"OS_SYSTEM_SCOPE"
	"OS_PROJECT_ID"
	"OS_PROJECT_NAME"
	"OS_CLOUD"
)

cat > $TEST_MANIFEST_PATH/cloud-credentials.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cloud-credentials
  namespace: basic-present-record
type: Opaque
data:
EOF

for NAME in ${OSENV[@]}
do
	VALUE=${!NAME}
	if [ -n "${VALUE}" ]; then
		echo "  ${NAME}=${VALUE}" >> ${ETC_DIR}/cloud-credentials.yaml
	fi
done

cat > $TEST_MANIFEST_PATH/config.json <<EOF
{
  "verify": false,
  "ttl": 600
}
EOF

TEST_ZONE_NAME="${TEST_ZONE_NAME}." TEST_MANIFEST_PATH=$TEST_MANIFEST_PATH go test .

popd