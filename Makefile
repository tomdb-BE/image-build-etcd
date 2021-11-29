SEVERITIES = HIGH,CRITICAL

ifeq ($(ARCH),)
ARCH=$(shell go env GOARCH)
endif

ifeq ($(ARCH),"arm64")
ETCD_UNSUPPORTED_ARCH=$(ARCH)
endif

BUILD_META ?= -multiarch-build$(shell date +%Y%m%d)
ORG ?= rancher
PKG ?= go.etcd.io/etcd
UBI_IMAGE ?= registry.access.redhat.com/ubi8/ubi-minimal:latest
GOLANG_VERSION ?= v1.16.10b7-multiarch
SRC ?= github.com/tomdb-be/etcd
TAG ?= v3.5.1-k3s1$(BUILD_META)

ifneq ($(DRONE_TAG),)
TAG := $(DRONE_TAG)
endif

ifeq (,$(filter %$(BUILD_META),$(TAG)))
$(error TAG needs to end with build metadata: $(BUILD_META))
endif

.PHONY: image-build
image-build:
	docker build \
		--build-arg PKG=$(PKG) \
		--build-arg SRC=$(SRC) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--build-arg ARCH=$(ARCH) \
		--build-arg ETCD_UNSUPPORTED_ARCH=$(ETCD_UNSUPPORTED_ARCH) \
                --build-arg GO_IMAGE=$(ORG)/hardened-build-base:$(GOLANG_VERSION) \
                --build-arg UBI_IMAGE=$(UBI_IMAGE) \
		--tag $(ORG)/hardened-etcd:$(TAG) \
		--tag $(ORG)/hardened-etcd:$(TAG)-$(ARCH) \
	.

.PHONY: image-push
image-push:
	docker push $(ORG)/hardened-etcd:$(TAG)-$(ARCH)

.PHONY: image-manifest
image-manifest:
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create --amend \
		$(ORG)/hardened-etcd:$(TAG) \
		$(ORG)/hardened-etcd:$(TAG)-$(ARCH)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest push \
		$(ORG)/hardened-etcd:$(TAG)

.PHONY: image-scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --ignore-unfixed $(ORG)/hardened-etcd:$(TAG)
