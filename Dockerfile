ARG UBI_IMAGE
ARG GO_IMAGE

FROM ${UBI_IMAGE} as ubi
FROM ${GO_IMAGE} as builder
# setup required packages
RUN set -x \
 && apk --no-cache add \
    file \
    gcc \
    git \
    libselinux-dev \
    libseccomp-dev \
    make
# setup the build
ARG PKG=go.etcd.io/etcd
ARG SRC=github.com/rancher/etcd
ARG TAG="v3.4.13-k3s1"
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
# build and assert statically linked executable(s)
WORKDIR $GOPATH/src/${PKG}/server
RUN go mod vendor \
 && export GO_LDFLAGS="-linkmode=external -X ${PKG}/version.GitSHA=$(git rev-parse --short HEAD)" \
 && go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o ../bin/etcd .
WORKDIR $GOPATH/src/${PKG}/etcdctl
RUN go mod vendor \
 && export GO_LDFLAGS="-linkmode=external -X ${PKG}/version.GitSHA=$(git rev-parse --short HEAD)" \
 && go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o ../bin/etcdctl .
WORKDIR $GOPATH/src/${PKG}
RUN go-assert-static.sh bin/*
RUN go-assert-boring.sh bin/*
RUN install -s bin/* /usr/local/bin
RUN etcd --version

FROM ubi
ENV ETCD_UNSUPPORTED_ARCH=arm64
RUN yum update -y && \
    rm -rf /var/cache/yum
COPY --from=builder /usr/local/bin/ /usr/local/bin/
