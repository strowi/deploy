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
# renovate: datasource=github-releases depName=a8m/envsubst versioning=loose
ENV ENVSUBST_VERSION="v1.2.0"
RUN curl -L https://github.com/a8m/envsubst/releases/download/v${ENVSUBST_VERSION}/envsubst-`uname -s`-`uname -m` -o /usr/local/bin/envsubst \
  && chmod +x /usr/local/bin/envsubst

# install consul
# renovate: datasource=github-releases depName=mantl/consul-cli versioning=loose
ENV CONSUL_CLI_VERSION="v0.3.1"
RUN apk --update --no-cache add jq \
  && curl -L https://github.com/mantl/consul-cli/releases/download/${CONSUL_CLI_VERSION}/consul-cli_${CONSUL_CLI_VERSION##v}_linux_amd64.tar.gz \
  | tar xvz --strip-components=1 -C /usr/local/bin/ \
  && consul-cli version

# install rancher
# renovate: datasource=github-releases depName=rancher/cli versioning=loose
ENV RANCHER_CLI_VERSION="v2.4.13"
RUN curl -L https://github.com/rancher/cli/releases/download/${RANCHER_CLI_VERSION}/rancher-linux-amd64-${RANCHER_CLI_VERSION}.tar.gz \
  | tar xvz --strip-components=2 \
  && mv rancher /usr/local/bin/rancher \
  && rancher --version

# install docker-compose
# renovate: datasource=github-releases depName=docker/compose versioning=loose
ENV DOCKER_COMPOSE_VERSION="1.28.5"
RUN curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64 \
    -o /usr/local/bin/docker-compose \
  && chmod 0755 /usr/local/bin/docker-compose

# install kubectl
# renovate: datasource=github-tags depName=kubernetes/kubectl versioning=loose
ENV KUBECTL_VERSION="1.20.5"
RUN curl -L -o /usr/local/bin/kubectl "https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
  && chmod 0755 /usr/local/bin/kubectl \
  && kubectl version --client

# install helm
# renovate: datasource=github-releases depName=helm/helm versioning=loose
ENV HELM_VERSION="v3.7.1"
RUN curl --silent -L "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
  | tar xzv --strip-components=1 -C /usr/local/bin/ linux-amd64/helm

# renovate: datasource=github-tags depName=shopify/krane versioning=loose
ENV KRANE_VERSION="2.3.0"
ARG BUILD_DEPS="g++ make ruby-dev ruby-bundler"
RUN mkdir -p /var/cache/apk \
  && apk update \
  && apk --no-cache add $BUILD_DEPS ruby-rake \
  && gem install \
    ejson \
    json \
    bigdecimal \
    rdoc \
  && gem install --no-document krane -v ${KRANE_VERSION} \
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
