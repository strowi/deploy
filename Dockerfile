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
ENV CONSUL_CLI_VERSION="0.3.1"
ENV CONSUL_MD5="cbeb30c2f2794dd98ef01f53b2e81d20"
RUN apk --update --no-cache add jq \
  && curl -L https://github.com/mantl/consul-cli/releases/download/v${CONSUL_CLI_VERSION}/consul-cli_${CONSUL_CLI_VERSION}_linux_amd64.tar.gz \
  | tar xvz --strip-components=1 -C /usr/local/bin/ \
  && echo "${CONSUL_MD5}  /usr/local/bin/consul-cli"  | md5sum -c

# install rancher
ENV RANCHER_CLI_VERSION="2.0.6"
ENV RANCHER_CLI_MD5="bf7dfb531b68ba9cc825e9e631e37be8"
RUN curl -L https://releases.rancher.com/cli2/v${RANCHER_CLI_VERSION}/rancher-linux-amd64-v${RANCHER_CLI_VERSION}.tar.gz \
  | tar xvz --strip-components=2 \
  && mv rancher /usr/local/bin/rancher \
  && rancher --version \
  && echo "${RANCHER_CLI_MD5}  /usr/local/bin/rancher" | md5sum -c

# install docker-compose
ENV DOCKER_COMPOSE_MD5="7048a965a86e6eed1622e0990e9a7ab4"
ENV DOCKER_COMPOSE_VERSION="1.24.1"
RUN curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64 \
    -o /usr/local/bin/docker-compose \
  && chmod 0755 /usr/local/bin/docker-compose \
  && echo "${DOCKER_COMPOSE_MD5}  /usr/local/bin/docker-compose" | md5sum -c

# install kubectl
# curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
ENV KUBECTL_VERSION="1.18.14"
ENV KUBECTL_MD5="a984b3494631876c0f2371ea44324b6b"
RUN curl -L -o /usr/local/bin/kubectl "https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
  && chmod 0755 /usr/local/bin/kubectl \
  && kubectl version --client \
  && echo "${KUBECTL_MD5}  /usr/local/bin/kubectl" | md5sum -c

ENV HELM_VERSION="3.5.2"
RUN curl --silent -L "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
  | tar xzv --strip-components=1 -C /usr/local/bin/ linux-amd64/helm

#ENV KRANE_DEPLOY_VERSION="2.1.5"
ARG BUILD_DEPS="g++ make ruby-dev ruby-bundler"
RUN mkdir -p /var/cache/apk \
  && apk update \
  && apk --no-cache add $BUILD_DEPS ruby-rake \
  && git clone https://github.com/strowi/kubernetes-deploy /tmp/krane \
  && cd /tmp/krane \
  && git checkout dynamic-cluster-url \
  && rake build \
  && gem install --no-document pkg/krane-2.1.7.gem \
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
