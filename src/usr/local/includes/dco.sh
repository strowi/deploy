#!/bin/bash

set -e

# installs docker-compose on the remote system
install_dco(){
  echo -e "######################################################################################################"

  for HOST in ${SSH_REMOTE}; do
    echo -en "## installing docker-compose on: $HOST     "
    ${SSH_CMD} ${SSH_USERNAME}@${HOST} "mkdir -p /home/${SSH_USERNAME}/.local/bin \
      && which $(groups) && ( groups|grep -q docker || sudo gpasswd -a ${SSH_USERNAME} docker) ||  echo 'no groups-cmd found -> assuming RancherOS'"
    rsync -avzz /usr/local/bin/docker-compose ${SSH_USERNAME}@${HOST}:/home/${SSH_USERNAME}/.local/bin/docker-compose

  done
  echo -e "######################################################################################################"
}

# runs docker system prune -fa
docker_prune(){
  for HOST in ${SSH_REMOTE}; do
    echo -en "## pruning docker-system on: $HOST     "

    ${SSH_CMD} ${SSH_USERNAME}@${HOST} \
      'docker system prune -fa  || echo "# WARN: docker system prune -a failed (docker version current enough?)"'
  done
    echo -e "######################################################################################################"
}

# deploys docker-compose.yml
# 1. rsync files
# 2. docker login to registry
# 3. copy CX_* variables from CI to .env-variables without CX_
# 4. run deploy.pre.sh
# 5. run docker-compose pull + up
# 6. run deploy.post.sh
# 7. write metrics
deploy_dco(){
  for HOST in ${SSH_REMOTE}; do
    echo -e "## deploying to: ${SSH_USERNAME}@${HOST}:${SSH_REMOTE_DST} \n"
    echo -en "## rsync                                                  \n"

    if [[ -z "${DRY_RUN}" ]]; then
      ${SSH_CMD} ${SSH_USERNAME}@${HOST} "mkdir -p ${SSH_REMOTE_DST}"
      test -f .rsync \
        && rsync --verbose --delete -a \
          -e "ssh -q -o StrictHostKeyChecking=no" \
          --include-from=.rsync ./ ${SSH_USERNAME}@${HOST}:${SSH_REMOTE_DST}

      echo -en "\n## docker login                                           \n"
      ${SSH_CMD} ${SSH_USERNAME}@${HOST} "cd ${SSH_REMOTE_DST} && set -ae && docker login -u \"$CI_REGISTRY_USER\" -p \"$CI_REGISTRY_PASSWORD\" \"$CI_REGISTRY\"" \

      echo -en "\n## copying CX_* variables to ${SSH_USERNAME}@${HOST}:${SSH_REMOTE_DST}/.env"
      env|grep "^CX_" | sed 's/^CX_//g' | ${SSH_CMD} ${SSH_USERNAME}@${HOST} "cat > ${SSH_REMOTE_DST}/.env"

      echo -en "\n## pre-deploy                      "
      ${SSH_CMD} ${SSH_USERNAME}@${HOST} "cd ${SSH_REMOTE_DST} && set -ae && test -x ./deploy.pre.sh && ( ./deploy.pre.sh || exit 1) || echo 'no deploy.pre.sh found, not executing'"


      echo -en "\n## docker-compose pull/up                                 \n"
      ${SSH_CMD} ${SSH_USERNAME}@${HOST} "cd ${SSH_REMOTE_DST} && set -ae && /home/${SSH_USERNAME}/.local/bin/docker-compose ${DOCKER_OPTS_PRE} pull && /home/${SSH_USERNAME}/.local/bin/docker-compose ${DOCKER_OPTS_PRE} up -d --remove-orphans --no-build"

      echo -en "\n## post-deploy                      "
      ${SSH_CMD} ${SSH_USERNAME}@${HOST} "cd ${SSH_REMOTE_DST} && set -ae && test -x ./deploy.post.sh && ( ./deploy.post.sh || exit 1 ) || echo 'no deploy.post.sh found, not executing'"

      echo "ck_deployment{type=\"dco\", app=\"${CI_PROJECT_PATH}\"} $(date +%s)" > /tmp/metrics
      echo -e "######################################################################################################"
    else
      echo "## running in DRY_RUN mode... not deploying "
    fi

  done
}
