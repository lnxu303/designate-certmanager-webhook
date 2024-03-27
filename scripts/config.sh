#!/bin/bash
CURDIR=$(dirname $0)
TEST_MANIFEST_PATH=_test/kubebuilder/designate

curl -fsSL "$1" -o kubebuilder-tools.tar.gz

mkdir -p _test/kubebuilder/godaddy
cd _test
tar -xvf ../kubebuilder-tools.tar.gz
cd ..
rm kubebuilder-tools.tar.gz

cat > ${TEST_MANIFEST_PATH}/config.json <<EOF
{
  "verify": true,
  "ttl": 600
}
EOF
