IMAGE_NAME := "syseleven/designate-certmanager-webhook"
IMAGE_TAG  ?= $(shell git describe --tags --always --dirty)

OUT := $(shell pwd)/_out

$(shell mkdir -p "$(OUT)")

build: check
	docker build -t "$(IMAGE_NAME):$(IMAGE_TAG)" .

check:
	@if test -n "$$(find . -not \( \( -wholename "./vendor" \) -prune \) -name "*.go" | xargs gofmt -l)"; then \
		find . -not \( \( -wholename "./vendor" \) -prune \) -name "*.go" | xargs gofmt -d; \
		exit 1; \
	fi

test:
	go test -v .

ci-push:
	echo "$$DOCKER_PASSWORD" | docker login -u "$$DOCKER_USERNAME" --password-stdin
	docker push "$(IMAGE_NAME):$(IMAGE_TAG)"

.PHONY: helm-install
helm-install:
	helm upgrade \
		-i certmgr-wh \
		--namespace certmgr-wh \
		--set image.repository=$(IMAGE_NAME) \
		--set image.tag="$(IMAGE_TAG)" \
		deploy/designate-certmanager-webhook

.PHONY: helm-diff
helm-diff:
	helm diff \
		--allow-unreleased upgrade \
		--namespace certmgr-wh \
		--set image.repository=$(IMAGE_NAME) \
		--set image.tag="$(IMAGE_TAG)" \
		certmgr-wh \
		deploy/designate-certmanager-webhook

.PHONY: helm-delete
helm-delete:
	helm delete --purge certmgr-wh

.PHONY: rendered-manifest.yaml
rendered-manifest.yaml:
	helm template \
		--namespace certmgr-webhook \
		--name certmgr-webhook \
		--set image.repository=$(IMAGE_NAME) \
		--set image.tag="$(IMAGE_TAG)" \
		deploy/designate-certmanager-webhook > "$(OUT)/rendered-manifest.yaml"
