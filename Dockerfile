FROM ruby:alpine
LABEL maintainer="Roman v. Gemmeren <roman.van-gemmeren@chefkoch.de>"


ENV PATH="$PATH:/usr/local/bundle/bin/"
ENV PUSHGATEWAY=""
ARG BUILD_DEPS="g++ make"

# install defaults
RUN apk --no-cache --update add  \
  xz \
  bash \
  openssl \
  openssh-client \
  curl \
  tar \
  gzip \
  git \
  gnupg \
  sed \
  bash \
  rsync \
  ca-certificates

# install rancher-compose
ENV RANCHER_COMPOSE_VERSION="v0.12.5"
ENV RANCHER_COMPOSE_MD5="91bc9f3fda699febc39191a2869ed361"

RUN curl -L https://github.com/rancher/rancher-compose/releases/download/${RANCHER_COMPOSE_VERSION}/rancher-compose-linux-amd64-${RANCHER_COMPOSE_VERSION}.tar.gz \
    | tar -zx --strip-components=2 -C /usr/local/bin/ \
  && echo "${RANCHER_COMPOSE_MD5}  /usr/local/bin/rancher-compose" | md5sum -c

# install docker-compose
ENV DOCKER_COMPOSE_MD5="52dcec1c78a1739986b170da3ba2f4d5"
ENV DOCKER_COMPOSE_VERSION="1.21.2"
RUN curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64 \
    -o /usr/local/bin/docker-compose \
  && chmod +x /usr/local/bin/docker-compose \
  && echo "${DOCKER_COMPOSE_MD5}  /usr/local/bin/docker-compose" | md5sum -c

# install kubectl
#curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
ENV KUBERNETES_VERSION="1.11.1"
RUN curl -L -o /usr/local/bin/kubectl "https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl" \
  && chmod +x /usr/local/bin/kubectl \
  && kubectl version --client

ENV ENVSUBST_VERSION="1.1.0"
RUN curl -L -o /usr/local/bin/envsubst "https://github.com/a8m/envsubst/releases/download/v${ENVSUBST_VERSION}/envsubst-Linux-x86_64" \
  && chmod +x /usr/local/bin/envsubst

RUN apk --update --no-cache add $BUILD_DEPS \
  && gem install --no-document \
    kubernetes-deploy \
    ejson \
  && gem cleanup  \
  && apk del $BUILD_DEPS \
  && rm -fr \
    /var/cache/* \
    /usr/local/bundle/cache \
    /root/.gem


COPY src/ /
