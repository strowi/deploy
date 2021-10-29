FROM bitnami/kubectl:1.20.5

FROM alpine:3.13

ENV PATH="$PATH:/usr/local/bundle/bin/"
ENV PUSHGATEWAY=""
ENV CONSUL_SERVER=""

# awscli comes from
# echo "@community http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories

RUN apk --update --no-cache add \
    git-crypt \
    gnupg \
    xz \
    bash \
    openssl \
    openssh-client \
    curl \
    tar \
    gettext \
    gzip \
    git \
    sed \
    rsync \
    ca-certificates \
    ruby \
    ruby-etc \
  && rm -fr \
    /var/cache/*

# envsubst
RUN curl -L https://github.com/a8m/envsubst/releases/download/v1.1.0/envsubst-`uname -s`-`uname -m` -o /usr/local/bin/envsubst \
  && chmod +x /usr/local/bin/envsubst

# install consul
# renovate: datasource=repology depName=openpkg_current/consul-cli versioning=loose
ENV CONSUL_CLI_VERSION="0.3.1"

RUN apk --update --no-cache add jq \
  && curl -L https://github.com/mantl/consul-cli/releases/download/v${CONSUL_CLI_VERSION}/consul-cli_${CONSUL_CLI_VERSION}_linux_amd64.tar.gz \
  | tar xvz --strip-components=1 -C /usr/local/bin/

# install rancher
ENV RANCHER_CLI_VERSION="2.0.6"
ENV RANCHER_CLI_MD5="bf7dfb531b68ba9cc825e9e631e37be8"
RUN curl -L https://releases.rancher.com/cli2/v${RANCHER_CLI_VERSION}/rancher-linux-amd64-v${RANCHER_CLI_VERSION}.tar.gz \
  | tar xvz --strip-components=2 \
  && mv rancher /usr/local/bin/rancher \
  && rancher --version \
  && echo "${RANCHER_CLI_MD5}  /usr/local/bin/rancher" | md5sum -c

# install docker-compose
ENV DOCKER_COMPOSE_MD5="8a50dee378793d19c8e0b634a74a8660"
ENV DOCKER_COMPOSE_VERSION="1.28.5"
RUN curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64 \
    -o /usr/local/bin/docker-compose \
  && chmod 0755 /usr/local/bin/docker-compose \
  && echo "${DOCKER_COMPOSE_MD5}  /usr/local/bin/docker-compose" | md5sum -c

# install kubectl
# curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
ENV KUBECTL_VERSION="1.20.5"
ENV KUBECTL_MD5="5ef4b0953a6efeb4cf6a629e3e6486ea"
COPY --from=0 /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/kubectl
RUN kubectl version --client

# renovate: datasource=repology depName=alpine_edge/helm versioning=loose
ENV HELM_VERSION="3.5.4"
RUN curl --silent -L "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
  | tar xzv --strip-components=1 -C /usr/local/bin/ linux-amd64/helm

# renovate: datasource=repology depName=nix_unstable/krane versioning=loose
ENV KRANE_VERSION="2.3.0"
ARG BUILD_DEPS="g++ make ruby-dev ruby-bundler"
RUN mkdir -p /var/cache/apk \
  && apk update \
  && apk --no-cache add $BUILD_DEPS ruby-rake \
  && gem install --no-document krane:${KRANE_VERSION} \
    ejson \
    json \
    bigdecimal \
    rdoc \
  && gem uninstall bundler rdoc \
  && gem cleanup  \
  && apk del --purge ${BUILD_DEPS} \
  && rm -fr \
    /var/cache/* \
    /usr/local/bundle/cache \
    /root/.gem \
  && mkdir -p /var/cache/apk


COPY src/ /

RUN find /usr -type d -exec chmod go-w {} \; \
  &&  find /usr/local/ -type f -exec chmod 0755 {} \;
