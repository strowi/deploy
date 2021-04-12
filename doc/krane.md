<!-- markdownlint-disable MD013 -->
# Deploy-K8 (krane)

- ref: [shopify/krane](https://github.com/shopify/krane/)

## Features

(erb-)rendered to $container:$PWD/.deploy/kranea
deployed from push metrics (if any)

- preps KUBE_CONTEXT from KUBE_(URL|TOKEN|NAMESPACE) or KUBECONFIaG
- (preps configMaps)
- adds registry-credentials from `CK_REGISTRY_SECRET_BASE64_*` variables
- imports WOK-variables from `project.yml` to environment-variables
- replaces all environment variables in manifests-folder:
  - copy
    `$KUBE_MANIFEST_DIR`      -> `container:/tmp/source/manifests`
  - envsubst
    `$KUBE_MANIFEST_DIR`      -> `$container:$PWD/.deploy/envsubst`
    **WATCH OUT** this will replace **ALL** "$XYZ", you can escape with "$$XYZ"
  - ERB-render
    `$container:$PWD/.deploy` -> `$container:$PWD/.deploy/krane`
- deploys **global resources** from `$container:$PWD/.deploy/krane/global`
- deploys **namespaced** resources from `$container:$PWD/.deploy/krane/`
- push metrics to our pushgateway

## Configuration

Configuration is done via **environment variables**:

- **KUBE_MANIFESTS_DIR**: Optional. The files where the deployment runner
  looks for the Kubernetes manifests.
  Default: `$PWD/manifests`
- **KUBE_CONFIGMAP_DIR**: Optional. Every file + sub-folder will become a
  ConfigMap named after the file / sub-folder (*WARNING*: No recursion
  supported from kubernetes so far).
  Will be copied to `$container:/tmp/deploy/configmaps`.
  Default `$PWD/configmaps`
  **NO variable substition**
- **KUBE_BUILD_DIR**: Debugging. The deployment runner expands all environment
  variables within the Kubernetes manifests. The resulting files are stored
  in the build dir.
  Default: `$container:$PWD/.deploy`
- **KUBE_NAMESPACE**: The Kubernetes namespace where the Kubernetes manifests
  should be deployed to.
- **KUBE_TOKEN**, **KUBE_URL**: Credentials for the Kubernetes cluster.
- **KUBE_CONTEXT**: When no `KUBE_TOKEN` and `KUBE_URL` are given the deployment
  runner will just select this context. This makes only sense when a valid
  kubeconfig file is mounted in the container.
- **KRANE_DEPLOY_OPTIONS**: Optional. Additional options to `krane`.
- **DRY_RUN**: For Debugging purposes (if set won't deploy anything), *only in deploy-k8*
- **CK_REGISTRY_SECRET_BASE64_hub_registry_net**: base64-encoded string for
  registry-credentials, will be templated into the manifests folder.
  Example:

```bash
~> kubectl create secret docker-registry
   hub.registry.net --docker-server=hub.registry.net
   --docker-username=abc --docker-password=xyz
   -o yaml --dry-run|base64 -w0
```

Will create `$TEMPLATE_SOURCE_DIR/00_imagePullSecret_hub_registry_net.yml` with:

```yaml
---
apiVersion: v1
data:
  .dockerconfigjson: ....
kind: Secret
metadata:
  creationTimestamp: null
  name: hub.registry.net
type: kubernetes.io/dockerconfigjson
```
## Secrets

See [upstream doc](https://github.com/shopify/krane#deploying-kubernetes-secrets-from-ejson) on howto encrypt your secrets passwords within git.

In short:

Create a secrets.json file within your manifest-folder:

```json
{
  "_public_key": "A75F9D8EB5FF793F51EF1D7427D2ABC8B5724078",
  "kubernetes_secrets": {
    "some-secret": {
      "_type": "Opaque",
      "data": ...
    },
    "some-more-secret": {
      "_type": "Opaque",
      "data": ...
    }
  }
}
```

Then run `ejson encrypt secrets.ejson` *before* commiting, and voila its encrypted.
With the pre-deployes private key, this will be decrypted during deployment. There can't be any linebreads etc..

## Workflow

- prepare kubectl context
- apply (fixed) rbac permissions
- prep configmaps
- prep/inject imagePullSecret
- import WOK-vars from `project.yml`
- copy `$KUBE_MANIFEST_DIR` to `$container:/tmp/source/manifests`
- envsubst `$KUBE_MANIFEST_DIR` to `$container:$PWD/.deploy`
- (erb-)rendered to `$container:$PWD/.deploy/krane`
- deployed from /.deploy/krane
- push metrics (if any)

## Gitlab-Pipeline

```yaml
---
deploy:k8s:ci:
  stage: deploy
  image: strowi/deploy
  environment:
    name: production
  variables:
    KUBE_MANIFESTS_DIR: manifests-production
  script:
    - deploy-k8
  only:
    - master
```

## Krane

### Options

```bash
~> krane --help
Krane commands:
  krane deploy NAMESPACE CONTEXT                        # Ship resources to a namespace
  krane global-deploy CONTEXT --selector='label=value'  # Ship non-namespaced resources to a cluster
  krane help [COMMAND]                                  # Describe available commands or one specific command
  krane render                                          # Render templates
  krane restart NAMESPACE CONTEXT                       # Restart the pods in one or more deployments
  krane run NAMESPACE CONTEXT f, --template=TEMPLATE    # Run a pod that exits upon completing a task
  krane version                                         # Prints the version
```

<!-- ## Simple usage example

```bash
~>
    docker run --rm -ti \
      -e KUBE_NAMESPACE=... \
      -e KUBE_TOKEN=... \
      -e KUBE_URL=... \
      -e EJSON_PRIVATE_KEY=... \
      -e EJSON_PUBLIC_KEY=... \
      -w /src \
      -v $(pwd):/src \
      -v /etc/passwd:/etc/passwd:ro \
      -v /etc/group:/etc/group:ro \
      -u $(id -u) \
      strowi/deploy deploy-k8
``` -->

### global vs. namespaced deployments

Krane can deploy either global *or* namespaced resources, not both!
For normal dev-related tasks namespaced deployments should be enough.

If you need to deploy global resources like (cluster-)rolebindings, CRDs, etc.
you need to create a folder `manifests/global` which will be deployed globally
(supports rendering of erb-templates too).

As long as you've got the permissions, this will
render + deploy global and namespaced resources in this order.

**Important**: When deploying global resources, you *must* specify a
selector for the resources and have enough permissions to do so.

This is hard-coded to:

```bash
--selector env=${CI_ENVIRONMENT_SLUG},app=${CI_PROJECT_PATH_SLUG},branch=${CI_COMMIT_REF_SLUG}
```

Example:

```yaml
metadata:
  labels:
    env: ${CI_ENVIRONMENT_SLUG}
    app: ${CI_PROJECT_PATH_SLUG}
    branch: ${CI_COMMIT_REF_SLUG}
```

### ConfigMaps (experimental!)

With the supported configMapFromFolder, we can automagically create a
configmap from a folder or file. It will be written **directly** to
`KUBE_BUILD_DIR/configMap-$name.yml` and **NOT** be `**envsubst**ed.

**For now use simple folder/filenames as "(-|.)" are not supported in
HASH-variable names.**

```bash
⇒  tree
.
├── configmaps
│   └── blubb.txt
│   └── test-01
│       └── testfile.txt
```

will become:

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  creationTimestamp: null
  name: test-01
data:
  testfile.txt: |
    123123123
---
apiVersion: v1
kind: ConfigMap
metadata:
  creationTimestamp: null
  name: blubb
data:
  blubb.txt: |
    123
```

### How to reload

The deploymentscript will export a variable
`CONFIGMAP_*NAME_OF_CONFIGMAP*_HASH` replacing `-` with `_` :

- blubb -> `CONFIGMAP_BLUBB_HASH`
- test-01 -> `CONFIGMAP_TEST_01_HASH`

These can be used in the kubernetes-manifests annotations to force a restart
of the pod if this md5sum of the folder/file changed.

```yaml
---
spec:
  replicas: 1
  revisionHistoryLimit: 1
  template:
    metadata:
      labels:
        app: "$CI_ENVIRONMENT_SLUG"
        team: sys
      annotations:
        checksum/TEST: "$CONFIGMAP_TEST_HASH"
```
