#!/bin/bash

set -e

# dpely_rco
# 1. rsync files
# 2. test for RANCHER_* variables
# 4. run rancher-compose pull
# 5. run rancher-compose up
# 6. write metrics
deploy_rco(){
  echo -e "######################################################################################################"
  for HOST in ${SSH_REMOTE}; do
    echo -e "## deploying to: ${SSH_USERNAME}@${HOST}:${SSH_REMOTE_DST} \n"
    echo -en "## rsync                                                  \n"

    test -f .rsync \
      && rsync --verbose --delete -a \
        -e "ssh -q -o StrictHostKeyChecking=no" \
        --include-from=.rsync ./ ${SSH_USERNAME}@${HOST}:${SSH_REMOTE_DST}

    echo -e "######################################################################################################"
  done

  test -n "${RANCHER_URL}"        || ( echo "#### ERROR RANCHER_URL not set" && exit 1 )
  test -n "${RANCHER_ACCESS_KEY}" || ( echo "#### ERROR RANCHER_ACCESS_KEY not set" && exit 1 )
  test -n "${RANCHER_SECRET_KEY}" || ( echo "#### ERROR RANCHER_SECRET_KEY not set" && exit 1 )

  if [[ -z "${DRY_RUN}" ]]; then
    echo "## running rancher-compose ${RANCHER_OPTS_PRE} \
      pull -d "
    rancher-compose ${RANCHER_OPTS_PRE} \
      pull || echo "## ERROR: pull failed!"

    echo "## running rancher-compose ${RANCHER_OPTS_PRE} \
      up -d --force-upgrade --confirm-upgrade"
    rancher-compose ${RANCHER_OPTS_PRE} \
      up -d --force-upgrade --confirm-upgrade --interval 3000

    echo "ck_deployment{type=\"rco\", app=\"${CI_PROJECT_PATH}\"} $(date +%s)" > /tmp/metrics
  else
    echo "## running in DRY_RUN mode... not deploying "
  fi

  echo -e "\n# finished deploying to $CI_PROJECT_PATH ...  :D "
}
