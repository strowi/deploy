FROM bitnami/kubectl:1.28.12

FROM ruby:3.4 AS ruby

# renovate: datasource=github-tags depName=shopify/krane versioning=loose
ENV KRANE_VERSION="v3.7.2-fix-path"
RUN git clone -b $KRANE_VERSION https://github.com/strowi/krane.git /tmp/krane \
  && cd /tmp/krane \
  && bundler install \
  && gem build --output=/tmp/krane.gem

FROM alpine:3.21

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

ENV BUILD_DEPS="g++"
COPY --from=ruby /tmp/krane.gem /tmp/krane.gem
RUN apk add --no-cache $BUILD_DEPS \
  && gem install /tmp/krane.gem \
  && gem cleanup \
  && apk del $BUILD_DEPS \
  && rm -fr /tmp/*

COPY src/ /

RUN find /usr -type d -exec chmod go-w {} \; \
  &&  find /usr/local/ -type f -exec chmod 0755 {} \;
