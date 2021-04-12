# Docker-Compose

Without a remote docker port, files need to be copied to the destination server.

## Configuration

Configuration has to be done via **environment variables**.

* **DRY_RUN**: For Debugging purposes (if set won't deploy anything), do not use!

1. setup SSH private Key aus `$CI_SSH_PRIVATE_KEY` (in CI/Gitlab)
2. rsync files from .rsync to
  `$SSH_REMOTE_USER@$SSH_REMOTE:$SSH_REMOTE_DST` (multiple servers
  possible, defaults to $PWD as remote folder).

.rsync:

```bash
docker-compose.yml
.ckenv
- **
```

REMOTE:
3. syncs docker-compose from container to `~/.local/bin/docker-compose`
4. adds SSH_REMOTE_USER to docker group, if required and sudo is available
5. CX_* variables will echoed without the 'CX_'-part to
   `SSH_REMOTE_DST/.env`, so they will be available in docker-compose.yml.
6. run docker login with:
    -  user: "$CI_REGISTRY_USER"
    -  password "$CI_REGISTRY_PASSWORD"
    -  registry "$CI_REGISTRY"
7. run docker-compose pull
8. wenn deploy.post.sh vorhanden, ausführen
