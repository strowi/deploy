#!/bin/bash

set -e

# push_metrics $1
# $1 - path to a prometheus-compatible metrics-file
push_metrics(){
  if [[ -n "${PUSHGATEWAY}" ]]; then
    echo -e "\n# pushing metrics to ${PUSHGATEWAY}"

    set +e
    response=$( cat $1 | curl --silent --write-out %{http_code} --data-binary @- http://${PUSHGATEWAY}/metrics/job/deployment/instance/ci)

    set -e
    if [[ "$response" -ne 202 ]] ; then
      echo -e "\n## FAILED, is the Pushgateway available?"
      echo -e " - NOT FATAL, continuing... "
      echo -e "   ( if this happens repeatedly, ask your friendly neighbourhood sysadmin)"
    fi
    echo -e " - done, continuing... "
  else
    echo "Not rushing, but there is no Pushgateway defined!"
  fi
}

# envsubst_vars
# TEMPLATE_TARGET_DIR - destination folder
# TEMPLATE_SOURCE_DIR - source folder
envsubst_vars(){

  echo -e "\n# Templates:"
  mkdir -p $TEMPLATE_TARGET_DIR
  for file in $(find "$TEMPLATE_SOURCE_DIR"/* -maxdepth 1)
  do
    echo "## generating template for: $file -> $TEMPLATE_TARGET_DIR/$(basename $file)"
    envsubst < $file > "$TEMPLATE_TARGET_DIR/$(basename $file)"
  done
}

# setup_ssh
# sets up SSH-AGENT with CI_SSH_PRIVATE_KEY
setup_ssh(){
  echo "## setting up ssh-agen"
  export SSH_CMD="ssh -q -o StrictHostKeyChecking=no"

  if test -n "$CI_SSH_PRIVATE_KEY"; then
    which ssh-agent || ( apk --update --no-cache add bash rsync openssh ca-certificates )
    echo $?
    eval $(ssh-agent -s)
    echo $?
    echo "$CI_SSH_PRIVATE_KEY" | base64 -d | ssh-add - > /dev/null
    echo $?
    if [ -z "$SSH_AUTH_SOCK" ] ; then
      eval `ssh-agent -s`
      ssh-add
    fi
  fi
}
