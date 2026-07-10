# Deploy verification suites

Black-box checks run **after** a Kamal deploy. They do **not** replace local Minitest.

| Profile | When | Writes? | Contents |
|---------|------|---------|----------|
| `pre_prod` | After pre-prod deploy | Yes (tagged test data only) | HTTP smoke, Directus, Redis cache probe, optional auth+CRUD |
| `prod` | After prod deploy | **No** | HTTP smoke + API contracts; optional Directus GET |

**On failure:** print failures + write a markdown report under `tmp/deploy_verify/`.  
**No** auto-rollback, DNS change, or redeploy — humans decide.

## Quick start

```bash
# Pre-prod (defaults BASE_URL=http://gs-test.co.uk — use hosts file or set URL)
script/run_deploy_verify.sh pre_prod

# Against t4g IP with Host header
DEPLOY_VERIFY_BASE_URL=http://18.130.29.168 \
DEPLOY_VERIFY_HOST_HEADER=gs-test.co.uk \
script/run_deploy_verify.sh pre_prod

# Prod (read-only)
DEPLOY_VERIFY_BASE_URL=https://globalsymbols.com \
script/run_deploy_verify.sh prod
```

Optional: load secrets automatically from `.kamal/secrets-common` and `.kamal/secrets.pre-prod` if those files exist and env vars are unset.

### Pre-prod auth + CRUD

```bash
export DEPLOY_VERIFY_USER_EMAIL='your-test-user@example.com'
export DEPLOY_VERIFY_USER_PASSWORD='…'
script/run_deploy_verify.sh pre_prod
```

CRUD creates a symbolset named `Deploy Test deploy-test-<run-id>`, updates it, then deletes it.

### Directus

Uses `DIRECTUS_URL` + `DIRECTUS_TOKEN_CMS` (or `DEPLOY_VERIFY_DIRECTUS_*`).  
Checks `server/info` and `items/gs_languages`.

### Redis cache (pre-prod)

Uses `REDIS_IP`, `REDIS_PASSWORD`, `REDIS_CACHE_DB` (default **2**).  
Needs network reachability to Redis (often only from VPC / t4g). If unreachable, that check **fails with a clear message** (not silent pass).

Run from t4g if needed:

```bash
# on t4g, with repo or a copy of deploy_verify + env
REDIS_IP=172.31.13.8 REDIS_PASSWORD=… REDIS_CACHE_DB=2 \
DEPLOY_VERIFY_BASE_URL=http://127.0.0.1:3000 \  # or via proxy
  ruby deploy_verify/runner.rb pre_prod
```

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | All executed checks passed (skips ok) |
| 1 | One or more failures (notification; human decides action) |
| 2 | Bad usage |

## Layout

```text
deploy_verify/
  runner.rb
  lib/           # config, http, redis, reporter, csrf
  suites/        # pre_prod.rb, prod.rb
  README.md
script/run_deploy_verify.sh
```
