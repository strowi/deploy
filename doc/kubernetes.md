# Kubernetes Deployments

## Configuration

Configuration has to be done via **environment variables**.

* **KUBE_MANIFESTS_DIR**: Optional. The files where the deployment runner looks
  for the Kubernetes manifests.Will be copied to $container:/tmp/source/manifests.
(`$PWD/manifests`)
* **KUBE_CONFIGMAP_DIR**: Optional. Every file + sub-folder will become a
  ConfigMap named after the file / sub-folder (*WARNING*: No recursion supported
  from kubernetes so far). Will be copied to $container:/tmp/deploy/configmaps.
  *NO variable substition*
(`$PWD/configmaps`)
* **KUBE_BUILD_DIR**: Debugging. The deployment runner expands all environment
  variables within the Kubernetes manifests. The resulting files are stored in
  the build dir. (`$container:/tmp/deploy`)
* **KUBE_NAMESPACE**: The Kubernetes namespace where the Kubernetes manifests
  should be deployed to.
* **KUBE_TOKEN**, **KUBE_URL**: Credentials for the Kubernetes cluster.
* **KUBE_CONTEXT**: When no KUBE_TOKEN and KUBE_URL are given the deployment
  runner will just select this context. This makes only sense when a valid
  kubeconfig file is mounted in the container.
* **KUBE_DEPLOY_OPTIONS**: Optional. Additional options to kubernetes-deploy
* **DRY_RUN**: For Debugging purposes (if set, only templates are generated
  won't deploy anything).

 ```bash
 Usage: kubernetes-deploy [options]
        --bindings=BINDINGS          Expose additional variables to ERB templates (format: k1=v1,k2=v2, JSON string or file (JSON or YAML) path prefixed by '@')
        --skip-wait                  Skip verification of non-priority-resource success (not recommended)
        --allow-protected-ns         Enable deploys to default, kube-system, kube-public; requires --no-prune
        --no-prune                   Disable deletion of resources that do not appear in the template dir
        --template-dir=DIR           Set the template dir (default: config/deploy/$ENVIRONMENT)
        --verbose-log-prefix         Add [context][namespace] to the log prefix
        --max-watch-seconds=seconds  Timeout error is raised if it takes longer than the specified number of seconds
    -h, --help                       Print this help
    -v, --version                    Show version

 ```

## Simple usage example

```bash
~> docker run --rm \
  -e KUBE_NAMESPACE=... \
  -e KUBE_TOKEN=... \
  -e KUBE_URL=... \
  -w /src \
  -v $(pwd):/src \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/group:/etc/group:ro \
  -u $(id -u) \
  strowi/deploy deploy-k8
```

## ConfigMaps

With the supported configMapFromFolder, we can automagically create a configmap from a folder or file. It will be written **directly** to KUBE_BUILD_DIR/configMap-$name.yml and **NOT** be `envsubst`ed. 

**For now use simple folder/filenames as "(-|.)" are not supported
in HASH-variable names.**

```bash
⇒  tree
.
├── configmaps
│   └── blubb.txt
│   └── test-01
│       └── testfile.txt
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

### How to reload?
The deploymentscript will export a variable `CONFIGMAP_*NAME_OF_CONFIGMAP*_HASH`
replacing "-"" with "_" :

* blubb -> `CONFIGMAP_BLUBB_HASH`
* test-01 -> `CONFIGMAP_TEST_01_HASH`

These can be used in the kubernetes-manifests annotations to force a restart of
the pod if this md5sum of the folder/file changed:

```yaml
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
