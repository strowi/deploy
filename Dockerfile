FROM bitnami/kubectl:1.23.5

FROM alpine:3.16

ENV PATH="$PATH:/root/.gem/ruby/2.7.0/bin/"
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
RUN curl -L https://github.com/a8m/envsubst/releases/download/${ENVSUBST_VERSION}/envsubst-Linux-x86_64 -o /usr/local/bin/envsubst \
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
ENV RANCHER_CLI_VERSION="v2.6.4"
RUN curl -L https://github.com/rancher/cli/releases/download/${RANCHER_CLI_VERSION}/rancher-linux-amd64-${RANCHER_CLI_VERSION}.tar.gz \
  | tar xvz --strip-components=2 \
  && mv rancher /usr/local/bin/rancher \
  && rancher --version

# install docker-compose
# renovate: datasource=github-releases depName=docker/compose versioning=loose
ENV DOCKER_COMPOSE_VERSION="v2.4.1"
RUN curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64 \
    -o /usr/local/bin/docker-compose \
  && chmod 0755 /usr/local/bin/docker-compose

# install kubectl
COPY --from=0 /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/kubectl
RUN chmod 0755 /usr/local/bin/kubectl \
  && chown root:root /usr/local/bin/kubectl \
  && kubectl version --client

# install helm
# renovate: datasource=github-releases depName=helm/helm versioning=loose
ENV HELM_VERSION="v3.8.2"
RUN curl --silent -L "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
  | tar xzv --strip-components=1 -C /usr/local/bin/ linux-amd64/helm

# renovate: datasource=github-tags depName=shopify/krane versioning=loose
ENV KRANE_VERSION="v2.4.7"
ARG BUILD_DEPS="g++ make ruby-dev ruby-bundler"
RUN mkdir -p /var/cache/apk \
  && apk update \
  && apk --no-cache add $BUILD_DEPS ruby-rake \
  && gem install --no-document \
    ejson \
    json \
    bigdecimal \
    rdoc \
    activesupport:6.1.4.3 \
  && git clone -b fix-api-path-discovery https://github.com/strowi/krane.git /tmp/krane \
  && cd /tmp/krane \
  && gem build \
  && gem install krane:${KRANE_VERSION//v} \
  && gem uninstall bundler \
  && gem cleanup  \
  && apk del --purge ${BUILD_DEPS} \
  && rm -fr \
    /var/cache/* \
    /root/.gem/ruby/*/cache/* \
    /usr/local/bundle/cache \
  && mkdir -p /var/cache/apk \
  && krane version

COPY src/ /

RUN find /usr -type d -exec chmod go-w {} \; \
  &&  find /usr/local/ -type f -exec chmod 0755 {} \;
