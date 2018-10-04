# Deploy-Container

This is a general-purpose deploy-container for deploying *k8s/rancher-compose/docker-compose* with *gitlab*.

Executable scripts:
```
- deploy-k8 (Kubernetes, incl. default RBAC-Template)
- deploy-k8s-sys (SYS-Deployments)
- deploy-rco (rancher-compose)
- deploy-dco (docker-compose)
```

## Global Varia.ckbles (rco/dco/k8*)

.ckenv:
```
SSH_USERNAME=${CI_USER:-ci}
SSH_REMOTE=""
SSH_REMOTE_DST="$(basename $PWD)"

# Pushgateway address
PUSHGATEWAY=""
...
```

Variables determining the deployment-behavior. 


## How does it work?
Well.. 
Variables can either be specified in .ckenv, or via Gitlab.

- [kubernetes](doc/kubernetes.md)
- [docker-compose](doc/docker-compose.md)
- [rancher-compose](doc/rancher-compose.md)

