# Deploy verification suites

Ships **with the app image** at `/rails/deploy_verify/`.  
Runs **only on the matching app server** (or inside its web container).  
**Not for laptops** — runtime guard refuses non-allowlisted IPs.

| Profile | Allowed host (private IP) | Writes |
|---------|---------------------------|--------|
| `pre_prod` | `172.31.30.149` (t4g) | Optional CRUD + password-reset POST |
| `prod` | `172.31.6.238` (+ update when m7g ships) | **None** (GET/HEAD only) |

On fail: report + exit 1. No auto-remediation.

## Shared smoke (both profiles, read-only)

Beyond core `/`, `/search`, `/symbolsets`, `/about`, sign-in, and API paths:

- CMS/content: `/contact`, `/news`, `/projects`, `/developer`, `/knowledge-base`
- Auth: `/users/password/new` (GET only on prod)
- Search quality: `/search?query=car` must not 500 or dump raw objects
- Locale: `/?locale=nl` must apply Dutch chrome
- Symbol PNG download: resolves a label via API, then `GET …/symbols/:id.png?download=1`

## Pre-prod only writes

When `DEPLOY_VERIFY_USER_EMAIL` / `PASSWORD` are set:

- `POST /users/password` (reset for the bot user)
- Existing symbolset CRUD

## Why it ships with the app

`deploy_verify/` is **not** in `.dockerignore`, so every Kamal deploy includes:

```text
/rails/deploy_verify/runner.rb
/rails/deploy_verify/bin/run
/rails/deploy_verify/lib/*
/rails/deploy_verify/suites/*
```

No separate rsync from a laptop is required after the image that contains this code is deployed.

(`script/` is dockerignored; the entrypoint that matters in production is **`deploy_verify/bin/run`** inside the image.)

## How to run (on the server)

### Pre-prod (t4g)

```bash
ssh global-symbols-ec2-test-t4

WEB=$(docker ps -q -f name=gs-repo-web-pre-prod | head -1)
docker exec "$WEB" /rails/deploy_verify/bin/run pre_prod
```

Or host wrapper (also IP-guarded):

```bash
# if you keep a checkout with script/ on the host:
script/run_deploy_verify.sh pre_prod
```

### Prod

```bash
ssh <prod-rails-host>
WEB=$(docker ps -q -f name=gs-repo-web-production | head -1)
docker exec "$WEB" /rails/deploy_verify/bin/run prod
```

### Auth / CRUD (pre-prod only)

Preferred: set in `.kamal/secrets.pre-prod` and list under `env.secret` in `config/deploy.pre-prod.yml` (see `secrets.example`):

- `DEPLOY_VERIFY_USER_EMAIL`
- `DEPLOY_VERIFY_USER_PASSWORD`

After rollout, the web container has them; `script/gs-deploy` **verify** also passes host secrets into `docker exec`. Create a dedicated Devise bot user in the pre-prod DB with the same credentials (not a personal account).

Manual override:

```bash
docker exec \
  -e DEPLOY_VERIFY_USER_EMAIL='…' \
  -e DEPLOY_VERIFY_USER_PASSWORD='…' \
  "$WEB" /rails/deploy_verify/bin/run pre_prod
```

Container already has `REDIS_*` / `DIRECTUS_*` from Kamal.

## Defaults inside the container

| Variable | Pre-prod | Prod |
|----------|----------|------|
| Base URL | `http://kamal-proxy` (set by host script) or set explicitly | same pattern |
| Host header | `gs-test.co.uk` | `globalsymbols.com` |
| Redis cache DB | `2` | not used |

When using `docker exec` directly, set:

```bash
-e DEPLOY_VERIFY_BASE_URL=http://kamal-proxy \
-e DEPLOY_VERIFY_HOST_HEADER=gs-test.co.uk \
```

(Host script sets these for you.)

## Environment lock

`lib/runtime_guard.rb` refuses to run unless the host private IP is allowlisted.  
Override only for exceptional cases: `DEPLOY_VERIFY_ALLOWED_IPS=x.x.x.x`.

Exit code **3** = wrong environment (not a check failure).

## Reports

`/tmp/deploy_verify/` inside the container; host script copies to host `/tmp/deploy_verify/`.
