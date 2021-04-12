#!/bin/bash

set -e

prep_kube_domain() {
  echo -e "\n\n### setting up Kube-Context:"
  if [[ -n "${KUBE_TOKEN}" ]] && [[ -n "${KUBE_URL}" ]] && [[ -n "${KUBE_NAMESPACE}" ]]; then

    echo "  - found KUBE_(URL|NAMESPACE|TOKEN):"
    export KUBECONFIG=/tmp/deploy-kube-config
    touch $KUBECONFIG && chmod go-rwx $KUBECONFIG
    kubectl config set-cluster "$KUBE_NAMESPACE" --server="$KUBE_URL"
    kubectl config set-credentials "$KUBE_NAMESPACE" --token="$KUBE_TOKEN"
    kubectl config set-context "$KUBE_NAMESPACE" --cluster="$KUBE_NAMESPACE" --user="$KUBE_NAMESPACE" --namespace="$KUBE_NAMESPACE"
    kubectl config use-context "$KUBE_NAMESPACE"
    KUBE_CONTEXT="${KUBE_NAMESPACE}"

  elif [ -n "${KUBE_CONTEXT}" ]; then
    echo "## found only KUBE_CONTEXT, using ${KUBE_CONTEXT}"
  else
    echo "In order to deploy to Kubernetes, either the variables KUBE_(URL|NAMESPACE|TOKEN)"
    echo "or just the KUBE_CONTEXT variable must be set!"
    echo "You can do it in project settings or defining a secret variable at group, project or admin level"
    echo "You can also manually add it in .gitlab-ci.yml"
    false
  fi
}

# create configmap from folders in ${TEMPLATE_CONFIGMAP_DIR} with name $folder int ${TEMPLATE_TARGET_DIR}
prep_kube_configmaps() {
  echo -e "\n\n# Preparing Configmaps from folder: ${TEMPLATE_CONFIGMAP_DIR}"

  if [[ -d "${TEMPLATE_CONFIGMAP_DIR}/" ]]; then

    # shellcheck disable=SC2044
    for dir in $(find "${TEMPLATE_CONFIGMAP_DIR}/" -mindepth 1 -maxdepth 1 -type d); do

      CONFIGMAP="$(basename "$dir")"

      echo -e "  - configMap: ${dir} -> ${TEMPLATE_TARGET_DIR}/configMap-${CONFIGMAP}.yml -> $KUBE_NAMESPACE/${CONFIGMAP}"
      mkdir -p "${TEMPLATE_TARGET_DIR}"
      kubectl create configmap "${CONFIGMAP}" --from-file="${dir}" -o yaml --dry-run >"${TEMPLATE_TARGET_DIR}/configMap-${CONFIGMAP}.yml"

      # # create variable containing a checksum of the configmap
      CONFIGMAP_NAME="$(echo "${CONFIGMAP}" | sed -e 's/\(.*\)/\U\1/' -e 's/-/_/g')"
      # shellcheck disable=SC2140
      export "CONFIGMAP_${CONFIGMAP_NAME}"_HASH="$(find "${TEMPLATE_TARGET_DIR}/configMap-${CONFIGMAP}.yml" -type f -exec md5sum {} \; | md5sum | cut -f1 -d" ")"

    done
    # shellcheck disable=SC2044,SC2140
    for file in $(find "${TEMPLATE_CONFIGMAP_DIR}/" -maxdepth 1 -type f); do

      CONFIGMAP="$(basename "${file%.*}")"

      echo -e "  - configMap: ${file} -> ${TEMPLATE_TARGET_DIR}/configMap-${CONFIGMAP}.yml -> $KUBE_NAMESPACE/${CONFIGMAP}"
      mkdir -p "${TEMPLATE_TARGET_DIR}"
      kubectl create configmap "${CONFIGMAP}" --from-file="${file}" -o yaml --dry-run >"${TEMPLATE_TARGET_DIR}/configMap-${CONFIGMAP}.yml"

      # # create variable containing a checksum of the configmap
      CONFIGMAP_NAME="$(echo "${CONFIGMAP}" | sed -e 's/\(.*\)/\U\1/' -e 's/-/_/g')"
      export "CONFIGMAP_${CONFIGMAP_NAME}"_HASH="$(find "${TEMPLATE_TARGET_DIR}/configMap-${CONFIGMAP}.yml" -type f -exec md5sum {} \; | md5sum | cut -f1 -d" ")"

    done

    if env | grep -qi HASH; then
      echo -e "\n  - listing all configMap-HASH-variables: "
      env | grep -i -e HASH
    fi

    echo -e "\n# all configMaps created."
  else
    echo "  - no configMaps to deploy. ;)"
  fi
}

prep_kube_imagePullSecret() {

  echo -e "\n\n# adding registry-Credentials: "
  for regcred in $(env | grep CK_REGISTRY_SECRET_BASE64_); do

    # CK_REGISTRY_SECRET_BASE64_$X=  -> secret named $X
    REG_NAME="$(echo "$regcred" | sed -s -e 's/CK_REGISTRY_SECRET_BASE64_\(.*\)=\(.*\)/\1/g' | tr '[:upper:]' '[:lower:]')"

    echo -e "\n  - $REG_NAME"

    echo "${regcred#*=}" | base64 -d > "${TEMPLATE_SOURCE_DIR}/00_imagePullSecret_${REG_NAME}.yml"
  done
}

deploy_k8() {
  echo -e "\n\n\n## Deploying to Kubernetes:  ${CI_ENVIRONMENT_SLUG}"
  echo -e "\n$(krane version)"
  echo "# TIMESTAMP=${TIMESTAMP}"
  echo "# REVISION=${REVISION}"
  echo "# $(krane version)"

  # setup context
  echo -e "\n# testing k8s-connection:"
  if kubectl cluster-info; then

    # echo deploying global resources
    if [ -d "${TEMPLATE_TARGET_DIR}/global" ]; then

      echo -e "\n\n# deploying global resources... "

      echo "krane render -f=$TEMPLATE_TARGET_DIR/global | krane global-deploy ${KUBE_CONTEXT} --stdin  --selector env=${CI_ENVIRONMENT_SLUG},app=${CI_PROJECT_PATH_SLUG},branch=${CI_COMMIT_REF_SLUG} ${KRANE_DEPLOY_OPTIONS}"

      # shellcheck disable=SC2086
      krane render -f="$TEMPLATE_TARGET_DIR/global" \
        | krane global-deploy "${KUBE_CONTEXT}" \
        --stdin  \
        --selector "env=${CI_ENVIRONMENT_SLUG},app=${CI_PROJECT_PATH_SLUG},branch=${CI_COMMIT_REF_SLUG}" \
        ${KRANE_DEPLOY_OPTIONS}

    # echo deploying global resources
    elif [ -d "${TEMPLATE_TARGET_DIR}/globals" ]; then

      echo -e "\n# deploying globals resources... "

      echo "krane render -f=$TEMPLATE_TARGET_DIR/globals | krane global-deploy ${KUBE_CONTEXT} --stdin  --selector env=${CI_ENVIRONMENT_SLUG},app=${CI_PROJECT_PATH_SLUG},branch=${CI_COMMIT_REF_SLUG} ${KRANE_DEPLOY_OPTIONS}"

      # shellcheck disable=SC2086
      krane render -f="$TEMPLATE_TARGET_DIR/globals" \
        | krane global-deploy "${KUBE_CONTEXT}" \
        --stdin  \
        --selector "env=${CI_ENVIRONMENT_SLUG},app=${CI_PROJECT_PATH_SLUG},branch=${CI_COMMIT_REF_SLUG}" \
        ${KRANE_DEPLOY_OPTIONS}

    else
      echo "  - no global resources to deploy. "
    fi

    echo -e "\n# checking/creating namespace $KUBE_NAMESPACE"
    # create namespace if not exists
    test -z "${DRY_RUN}" && \
      ( kubectl get namespace "$KUBE_NAMESPACE" || kubectl create namespace "$KUBE_NAMESPACE" )


    # TODO only run if files exist
    # preparing ejson-secret
    if [[ -z "${DRY_RUN}" ]] && [ -n "${EJSON_PRIVATE_KEY}" ] && [ -n "${EJSON_PUBLIC_KEY}" ]; then
      # to keep 1 single variable in gitlab and not break existing global deployment
      #
      kubectl delete --namespace="$KUBE_NAMESPACE" --now secret ejson-keys || true
      kubectl create --namespace="$KUBE_NAMESPACE" secret generic ejson-keys --from-literal="$EJSON_PUBLIC_KEY=$EJSON_PRIVATE_KEY"
    fi

    # deploy
    echo -e "\n# deploying to $KUBE_NAMESPACE... "

    mkdir -p "${TEMPLATE_DEPLOY_DIR}"

    # secrets.ejson won't be rendered with krane render
    test -f "${TEMPLATE_TARGET_DIR}/secrets.ejson" \
      && cp "${TEMPLATE_TARGET_DIR}/secrets.ejson" "${TEMPLATE_DEPLOY_DIR}/secrets.ejson"

    krane render -f="$TEMPLATE_TARGET_DIR" > "${TEMPLATE_DEPLOY_DIR}/deploy.yml"

    # shellcheck disable=SC2086
    # TODO: fixit
    if [[ -z "${DRY_RUN}" ]]; then

      krane deploy "$KUBE_NAMESPACE" "${KUBE_CONTEXT}" -f "${TEMPLATE_DEPLOY_DIR}" \
        --no-verbose-log-prefix \
        ${KRANE_DEPLOY_OPTIONS}

      echo "ck_deployment{environment_url=\"${CI_ENVIRONMENT_URL}\", environment=\"${CI_ENVIRONMENT_SLUG}\", pipeline=\"${CI_PIPELINE_URL}\", namespace=\"${KUBE_NAMESPACE}\"} $(date +%s)" >/tmp/metrics
    fi

    echo -e "\n# finished deploying to NS $KUBE_NAMESPACE...  :D "
  else
    echo -e "\n# ERROR: connecting to cluster $KUBE_CONTEXT"
    exit 1
  fi
}

cleanup() {

  if [[ -z "${DRY_RUN}" ]]; then
    rm -fr \
      "${TEMPLATE_MANIFESTS_DIR}"\
      "${TEMPLATE_CONFIGMAP_DIR}"\
      "${TEMPLATE_TARGET_DIR}"\
      "${TEMPLATE_SOURCE_DIR}" \
      "${TEMPLATE_DEPLOY_DIR}"
  fi

}
