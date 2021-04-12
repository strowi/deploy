# Deploy-Container

Repo-Url: [https://gitlab.com/strowi/deploy](https://gitlab.com/strowi/deploy)

## Docker Image

Should be available on docker and gitlab:

* [strowi/deploy:latest](https://hub.docker.com/repository/docker/strowi/deploy)
* [registry.gitlab.com/strowi/deploy:latest](https://gitlab.com/strowi/deploy)

This is a general-purpose deploy-container for deploying *k8s/
docker-compose* with *gitlab*.

Executable scripts:

- `deploy-k8` (Kubernetes)
- `deploy-dco` (docker-compose)
- `consul_update` (monitoring-bare-metal)
- `setup_gpg` (will import the CI_GPG_PRIVATE_KEY to gpg (for git-crypt..))

```bash
CI_GPG_PRIVATE_KEY INFO:
pub   rsa3072 2018-10-31 [SC] [verfällt: 2025-10-28]
      XYZ
uid        [uneingeschränkt] ci (for.. you know.. ci and stuff) <strowi@hasnoname.de>
sub   rsa3072 2018-10-31 [E] [verfällt: 2025-10-28]

```

## How it works

Well.. read on:

- [kubernetes](doc/kubernetes.md)
- [docker-compose](doc/docker-compose.md)
- [consul](doc/consul.md)
- [AWS](doc/aws.md)

- [WOK-Compatibility](doc/wok.md)
