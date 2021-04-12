<!-- markdownlint-disable MD013 -->
# Consul-Updater

**For monitoring purposes only!**

This little script can be called from exporter-repositories to add their
endpoint(s) to consul (to be discovered by prometheus).

## Variables

```bash
CONSUL_SERVER="${CONSUL_SERVER:-}"

# service-name containing our endpoints/service_ids
SERVICE="$1"

# port to use for service
PORT="$2"
```

## What

consul (<http://consul-domain:8500)> keeps a list of services + endpoints.

1. When this script is called it removes all endpoints matching the filter
  `--remove=$TAG` (fallback is `$CI_PROJECT_PATH_SLUG`) from the named $service.
2. Next it adds the list of `$SSH_REMOTE`-Hosts with their port as endpoint
  to the service.

## How

Lets say we have previously deployed sys-monitoring-node-exporter to test01-02
with consul:

1st part:

```bash
~> export SSH_REMOTE="test01 test02 test03"
~> export CI_PROJECT_PATH_SLUG=sys-monitoring-node-exporter

~> ./consul_update node-exporter 9100 [--remove=TAG_REMOVE] [--tag=xyz]*

consul services deregister -http-addr=consul-domain:8500 -id test01-9100
consul services deregister -http-addr=consul-domain:8500 -id test02-9100
```

The existing endpoints with matching tag `TAG_REMOVE` will be removed from
consuls `node-exporter` service.

2nd part:
all `$SSH_REMOTE's` will be re-added, including test03 and the additional TAGs.

```bash
consul services register -http-addr=consul-domain:8500 -address=test01 -id=test1-9100 -name=node-exporter -port=9100 -tag team-sys -tag sys-monitoring-node-exporter ...

consul services register -http-addr=consul-domain:8500     -address=test02     -id=test2-9100     -name=node-exporter     -port=9100     -tag team-sys     -tag sys-monitoring-node-exporter ...

consul services register -http-addr=consul-domain:8500     -address=test03     -id=test3-9100     -name=node-exporter     -port=9100     -tag team-sys     -tag sys-monitoring-node-exporter ...
```

So in your exporter-deployment to bare-metal, in the deployment-stage call:

```yaml
---
  script:
    - deploy-dco
    - consul_update node-exporter 9100 (service-name port)
```

## Removal

If removing a complete service like "node-exporter", run the script manually
with an empty SSH_REMOTE and same args as in deployment:

```bash
~> src/usr/local/bin/consul_update node-exporter 9100 --remove=sys-monitoring-node-exporter
```
