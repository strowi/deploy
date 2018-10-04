## Rancher-Compose

### Configuration 
Configuration has to be done via **environment variables**.

* **DRY_RUN**: For Debugging purposes (if set won't deploy anything), do not use! 

1. setup SSH mit private Key aus $CI_SSH_PRIVATE_KEY (in Gitlab hinterlegt)
2. rsync der files aus .rsync auf den SSH_REMOTE (auch mehrere Server möglich) nach SSH_REMOTE_DST als SSH_REMOTE_USER:
.rsync
```
docker-compose.yml
.ckenv
- **
```
3. rancher-compose up gegen die Rancher-API ($CI_RANCHER_URL,$CI_RANCHER_ACCESS_KEY, $CI_RANCHER_SECRET_KEY)
