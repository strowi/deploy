# Helm (less highly experimental)

New initial support for helm has landed in `deploy-helm`. It works almost
similar to the existing deploy-k8*.

## short version

```yaml
---
deploy:helm:
  stage: deploy-ci
  image: strowi/deploy:latest
  environment:
    name: production
  script:
    - deploy-helm
  only:
    - master
```

## longer version

At first deploy-helm will:

- preps KUBE_CONTEXT from KUBE_(URL|TOKEN|NAMESPACE) or KUBECONFIG
- replaces all environment variables in following helm-files:
  - *difference*: will only replace vars that actually exist!
  - Chart.yaml|yml
  - values.yaml|yml
  - values-${CI_ENVIRONMENT_SLUG}.yaml|yml
  - `$HELM_CHART_DIR/`      -> `-$PWD/.deploy/envusbst`

- deploy the helm-chart like:

  ```bash
  ~> helm ${HELM_OPTIONS} \
    "${CI_ENVIRONMENT_SLUG}-${CI_PROJECT_KUBE_MANIFESTS_DIRNAME}" \
    "${HELM_CHART_DIR}"
  ```

## Configuration

Configuration is done via **environment variables**:

- **HELM_CHART_DIR**: Optional. The files where the deployment runner
  looks for the Kubernetes manifests.
  Default: `$PWD/helm`
- **HELM_BUILD_DIR**: Debugging. The deployment runner will replace *existing*
  variables in specific helm-files. The resulting files are stored
  in the build dir.
  Default: `$container:$PWD/.deploy`
- **HELM_OPTIONS**: Options used for installing/upgrading helm-chart. Default:
  `upgrade --install --atomic  --wait  --cleanup-on-fail  --history-max 2 --description "${CI_COMMIT_REF_SLUG}/${CI_COMMIT_SHORT_SHA:-no_sha_given}"  --namespace ${KUBE_NAMESPACE}"`
- **KUBE_NAMESPACE**: The Kubernetes namespace where the Kubernetes manifests
  should be deployed to.
- **KUBE_TOKEN**, **KUBE_URL**: Credentials for the Kubernetes cluster.
- **KUBE_CONTEXT**: When no `KUBE_TOKEN` and `KUBE_URL` are given the deployment
  runner will just select this context. This makes only sense when a valid
  kubeconfig file is mounted in the container.
- **DRY_RUN**: For Debugging purposes (if set won't deploy anything), *only in deploy-k8*
- **CK_REGISTRY_SECRET_BASE64_HUB_CHEFKOCH_NET**: base64-encoded string for
  registry-credentials. Can be injected into the values.yaml like:

### Examples

values.yaml:

```yaml
---
ck:
tag: "${CI_COMMIT_REF_SLUG}-${CI_COMMIT_SHORT_SHA}"
imagePullSecret: "${CK_REGISTRY_SECRET_BASE64_HUB_CHEFKOCH_NET}"
```

template/imagePullSecret.yaml:  

```yaml
---
{{- if .Values.ck}} {{- if .Values.ck.imagePullSecret}}
{{.Values.ck.imagePullSecret |b64dec}}
{{- end}}{{- end}}
```

Will deploy a helm-release named
`${CI_ENVIRONMENT_SLUG}-${CI_PROJECT_KUBE_MANIFESTS_DIRNAME}`
to $KUBE_NAMESPACE and prefix.

*INFO*: NO support for sensible data. Use git-crypt for that! And watch out for
the bugs ... :D

## Manual deployment

Just for reference: Running this via cli should look like:

```bash
Just learn how to use helm3...
```
