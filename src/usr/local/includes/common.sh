#!/bin/bash

set -e

# shellcheck source=src/usr/local/includes/yaml.sh
source /usr/local/includes/yaml.sh

# push_metrics $1
# $1 - path to a prometheus-compatible metrics-file
push_metrics() {
  if [[ -n "${PUSHGATEWAY}" ]] && [[ -f "/tmp/metrics" ]]; then
    echo -e "\n\n# pushing metrics to ${PUSHGATEWAY}"

    set +e
    # shellcheck disable=2002
    response=$( cat "$1" | curl --silent --write-out "%{http_code}" --data-binary @- "${PUSHGATEWAY}/metrics/job/deployment/instance/ci")

    set -e
    if [[ "$response" -ne 200 ]]; then
      echo -e "  - FAILED, got a $response is the Pushgateway available?"
      echo -e "    NOT FATAL, continuing... "
      echo -e "   ( if this happens repeatedly, ask your friendly neighbourhood sysadmin)"
    fi
    echo -e "  - done, continuing... "
  else
    echo "  - Pushgateway NOT defined, just saying...!"
  fi
}

# envsubst_vars
# TEMPLATE_TARGET_DIR - destination folder
# TEMPLATE_SOURCE_DIR - source folder
envsubst_vars() {

  cd "$TEMPLATE_SOURCE_DIR"
  mkdir -p "$TEMPLATE_TARGET_DIR"

  echo -e "\n\n# Templates:"

  # shellcheck disable=SC2044
  for dir in $(find ./ -type d); do
    echo "  - creating folder $dir -> $TEMPLATE_TARGET_DIR/$dir"
    mkdir -p "$TEMPLATE_TARGET_DIR/$dir"
  done

  # shellcheck disable=SC2044
  for file in $(find ./ -type f); do
    echo "  - envsubsting template for: $file -> $TEMPLATE_TARGET_DIR/$file"
    envsubst <"$file" >"$TEMPLATE_TARGET_DIR/$file"
  done
}

# setup_ssh
# sets up SSH-AGENT with CI_SSH_PRIVATE_KEY
setup_ssh() {
  # shellcheck disable=SC2028
  echo "\n\n# setting up ssh-agent"
  export SSH_CMD="ssh -q -o StrictHostKeyChecking=no"

  if test -n "$CI_SSH_PRIVATE_KEY"; then
    command -v ssh-agent || (apk --update --no-cache add bash rsync openssh ca-certificates)
    echo $?
    eval "$(ssh-agent -s)"
    echo $?
    echo "$CI_SSH_PRIVATE_KEY" | base64 -d | ssh-add - >/dev/null
    echo $?
    if [ -z "$SSH_AUTH_SOCK" ]; then
      eval "$(ssh-agent -s)"
      ssh-add
    fi
    # global ssh
    # - ignore host-keys
    # - forward agent
    # mkdir -p ~/.ssh
    # {
    #   echo -e "ForwardAgent yes"
    #   echo -e "StrictHostKeyChecking no"
    #   echo -e "User ${SSH_USERNAME}"

    #   # aws control-vpc bastion
    #   echo "Host *.control.aws.XYZ.net !bastion.control.aws.XYZ.net"
    #   echo "  ProxyCommand ssh -W %h:%p bastion.control.aws.XYZ.net"

    #   # aws control-prod-vpc bastion
    #   echo "Host *.control-prod.aws.XYZ.net !bastion.control-prod.aws.XYZ.net"
    #   echo "  ProxyCommand ssh -W %h:%p bastion.control-prod.aws.XYZ.net"
    # } >> ~/.ssh/config
  fi
}
