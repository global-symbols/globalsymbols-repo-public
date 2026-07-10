# Deploy verification suites

Black-box checks run **on the app server** after a Kamal deploy (not on your Mac).

| Profile | Host | Writes? | Contents |
|---------|------|---------|----------|
| `pre_prod` | t4g (`global-symbols-ec2-test-t4`) | Optional CRUD | HTTP via local proxy, Directus, Redis DB 2, auth/CRUD |
| `prod` | prod Rails host | **No** | HTTP via local proxy, API contracts, optional Directus GET |

**On failure:** markdown report + exit 1. **No** auto-rollback/DNS — human decides.

## Why on the server?

| Check | On server | From Mac |
|-------|-----------|----------|
| Rails via kamal-proxy | `http://127.0.0.1` + Host header | Needs hosts/VPN |
| Redis `172.31.13.8` | Reachable | Usually timed out |
| Same path as real traffic | Yes (local edge) | Partial |

## How to run

### A. From your laptop (syncs suite, runs on server)

```bash
# Pre-prod t4g
script/run_deploy_verify_remote.sh pre_prod

# With CRUD
DEPLOY_VERIFY_USER_EMAIL='…' DEPLOY_VERIFY_USER_PASSWORD='…' \
  script/run_deploy_verify_remote.sh pre_prod

# Prod (update SSH host when m7g is live: DEPLOY_VERIFY_SSH=…)
script/run_deploy_verify_remote.sh prod
```

### B. SSH to the server yourself

```bash
ssh global-symbols-ec2-test-t4
# after remote script has synced, or after image includes deploy_verify/:
bash /opt/gs-deploy-verify/run_deploy_verify.sh pre_prod
```

### C. Inside the web container (after image includes `deploy_verify/`)

```bash
# on server
WEB=$(docker ps -q -f name=gs-repo-web-pre-prod | head -1)
docker exec -e DEPLOY_VERIFY_BASE_URL=http://kamal-proxy \
  -e DEPLOY_VERIFY_HOST_HEADER=gs-test.co.uk \
  -e REDIS_IP -e REDIS_PASSWORD -e REDIS_CACHE_DB=2 \
  -e DIRECTUS_URL -e DIRECTUS_TOKEN_CMS \
  "$WEB" ruby /rails/deploy_verify/runner.rb pre_prod
```

`script/run_deploy_verify.sh` prefers this path when the file exists in the image.

## Defaults (on-server)

| Variable | Pre-prod default | Prod default |
|----------|------------------|--------------|
| `DEPLOY_VERIFY_BASE_URL` | `http://127.0.0.1` | `http://127.0.0.1` |
| `DEPLOY_VERIFY_HOST_HEADER` | `gs-test.co.uk` | `globalsymbols.com` |
| `REDIS_IP` | `172.31.13.8` | (Redis checks off) |
| `REDIS_CACHE_DB` | `2` | `3` (unused) |
| Directus URL | `https://cms.gs-test.co.uk` | `https://cms.globalsymbols.com` |

Env is **imported from the running web container** when possible (`REDIS_*`, `DIRECTUS_*`, …).

## Reports

Written to **`/tmp/deploy_verify/`** on the server.

## After each deploy (suggested)

```text
kamal deploy -d pre-prod --skip-push
script/run_deploy_verify_remote.sh pre_prod    # from laptop
# read report / NOTIFICATION lines — human decides next action
```
