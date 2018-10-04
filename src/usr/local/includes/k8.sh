#!/bin/bash

set -e

apply_rbac_permissions(){
  if [ "$BASENAME" == "deploy-k8" ]; then
    echo -e "\n# Applying rbac-edit.yml - Template to apply default RBAC-permissions"
    cp -v /templates/k8/rbac-edit.yml $TEMPLATE_SOURCE_DIR/
  fi

  echo -e "\n# Content of manifest folder: "
  ls -al $TEMPLATE_SOURCE_DIR/
  echo ""
}

prep_kube_domain() {
  echo -e "\n### setting up Kube-Context:"
  if [[ -n "${KUBE_TOKEN}" ]] && [[ -n "${KUBE_URL}" ]] && [[ -n "${KUBE_NAMESPACE}" ]]; then

    echo "## found KUBE_(URL|NAMESPACE|TOKEN):"
    export KUBECONFIG=/tmp/deploy-kube-config
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
prep_kube_configmaps(){
  echo -e "\n# Preparing Configmaps from folder: ${TEMPLATE_CONFIGMAP_DIR}"

  for dir in $(find ${TEMPLATE_CONFIGMAP_DIR}/ -mindepth 1 -maxdepth 1 -type d); do


    CONFIGMAP="$(basename $dir)"

    echo -e "## - configMap: ${dir} -> ${TEMPLATE_TARGET_DIR}/configMap-${CONFIGMAP}.yml -> $KUBE_NAMESPACE/${CONFIGMAP}"
    kubectl create configmap "${CONFIGMAP}" --from-file="${dir}" -o yaml --dry-run > ${TEMPLATE_TARGET_DIR}/configMap-${CONFIGMAP}.yml


    # # create variable containing a checksum of the configmap
    CONFIGMAP_NAME="$(echo "${CONFIGMAP}"| sed -e 's/\(.*\)/\U\1/' -e 's/-/_/g')"
    export "CONFIGMAP_${CONFIGMAP_NAME}"_HASH="$(find "$dir" -type f -exec md5sum {} \; | md5sum|cut -f1 -d" ")"

  done


  for file in $(find ${TEMPLATE_CONFIGMAP_DIR}/ -maxdepth 1 -type f); do


    CONFIGMAP="$(basename ${file%.*})"

    echo -e "## - configMap: ${file} -> ${TEMPLATE_TARGET_DIR}/configMap-${CONFIGMAP}.yml -> $KUBE_NAMESPACE/${CONFIGMAP}"
    kubectl create configmap "${CONFIGMAP}" --from-file="${file}" -o yaml --dry-run > ${TEMPLATE_TARGET_DIR}/configMap-${CONFIGMAP}.yml

    # # create variable containing a checksum of the configmap
    CONFIGMAP_NAME="$(echo "${CONFIGMAP}"| sed -e 's/\(.*\)/\U\1/' -e 's/-/_/g')"
    export "CONFIGMAP_${CONFIGMAP_NAME}"_HASH="$(find "$file" -type f -exec md5sum {} \; | md5sum|cut -f1 -d" ")"

  done

  echo -e "\n listing all configMap-HASH-variables: "
  env|grep -i -e HASH

  echo -e "\n# all configMaps created."
}


deploy_k8(){
  echo -e "\n## Deploying to Kubernetes"
  echo "# TIMESTAMP=${TIMESTAMP}"

  # setup context
  echo -e "\n# supported API-Versions:"
  if kubectl api-versions; then

    if [[ -z "${DRY_RUN}" ]]; then
      echo "\n# checking/creating namespace $KUBE_NAMESPACE"
      # create namespace if not exists
      kubectl get namespace "$KUBE_NAMESPACE" || kubectl create namespace "$KUBE_NAMESPACE"

      # deploy
      echo -e "\n# deploying to $KUBE_NAMESPACE... "

      kubernetes-deploy "$KUBE_NAMESPACE" "${KUBE_CONTEXT}" --template-dir=$TEMPLATE_TARGET_DIR ${KUBE_DEPLOY_OPTIONS}
      echo "ck_deployment{type=\"k8\", app=\"${KUBE_NAMESPACE}\"} $(date +%s)" > /tmp/metrics
    else
      echo "## running in DRY_RUN mode... not deploying "
    fi

    echo -e "\n# finished deploying to NS $KUBE_NAMESPACE...  :D "
  fi
}
