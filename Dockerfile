FROM bitnami/kubectl:1.28.12

FROM alpine:3.20

ENV PATH="$PATH:/root/.gem/ruby/2.7.0/bin/"

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
    diffutils \
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
ENV ENVSUBST_VERSION="v1.4.2"
RUN curl -L https://github.com/a8m/envsubst/releases/download/${ENVSUBST_VERSION}/envsubst-Linux-x86_64 -o /usr/local/bin/envsubst \
  && chmod +x /usr/local/bin/envsubst

# install rancher
# renovate: datasource=github-releases depName=rancher/cli versioning=loose
ENV RANCHER_CLI_VERSION="v2.8.4"
RUN curl -L https://github.com/rancher/cli/releases/download/${RANCHER_CLI_VERSION}/rancher-linux-amd64-${RANCHER_CLI_VERSION}.tar.gz \
  | tar xvz --strip-components=2 \
  && mv rancher /usr/local/bin/rancher \
  && rancher --version

# install kubectl
COPY --from=0 /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/kubectl
RUN chmod 0755 /usr/local/bin/kubectl \
  && chown root:root /usr/local/bin/kubectl \
  && kubectl version --client

# install helm
# renovate: datasource=github-releases depName=helm/helm versioning=loose
ENV HELM_VERSION="v3.15.3"
RUN curl --silent -L "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
  | tar xzv --strip-components=1 -C /usr/local/bin/ linux-amd64/helm

# renovate: datasource=github-tags depName=shopify/krane versioning=loose
ENV KRANE_VERSION="v3.6.0-fix-path"
ARG BUILD_DEPS="g++ make ruby-dev ruby-bundler"
RUN mkdir -p /var/cache/apk \
  && apk update \
  && apk --no-cache add $BUILD_DEPS ruby-rake linux-headers \
  && gem install --no-document \
    ejson \
    json \
    bigdecimal \
    rdoc \
    activesupport:6.1.4.3 \
  && git clone -b $KRANE_VERSION https://github.com/strowi/krane.git /tmp/krane \
  && cd /tmp/krane \
  && gem build --output=krane-${KRANE_VERSION//v}.gem \
  && gem install krane-${KRANE_VERSION//v}.gem \
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
