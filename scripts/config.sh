#!/bin/bash
CURDIR=$(dirname $0)
TEST_MANIFEST_PATH=_test/kubebuilder/designate

curl -fsSL "$1" -o kubebuilder-tools.tar.gz

mkdir -p _test/kubebuilder/godaddy
cd _test
tar -xvf ../kubebuilder-tools.tar.gz
cd ..
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
  name: godaddy-api-key
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

cat > ${TEST_MANIFEST_PATH}/config.json <<EOF
{
  "verify": true,
  "ttl": 600
}
EOF
