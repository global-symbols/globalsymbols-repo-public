# Kamal secrets + deploy CLI (local only)

## Secrets

1. Copy examples and fill values (do not commit):

```bash
cp .kamal/secrets.example .kamal/secrets-common
cp .kamal/secrets.example .kamal/secrets.pre-prod
# edit both files
```

2. Image/registry live in `config/deploy.yml` (`ghcr.io/global-symbols/globalsymbols-repo-internal`).

## Everyday deploy (recommended)

Always open the **interactive menu** (phases are not direct subcommands):

```bash
script/gs-deploy
```

That presents:

1. **Environment** — pre-prod or production  
2. **Action** — full wizard, or a single phase  
3. **Confirm** — summary, then start  

### Ship flow (build → push → rollout)

| Action | Where | Tool | What happens |
|--------|--------|------|----------------|
| **build** | Mac | host `docker build` | Image tagged locally (`:VERSION` + `:latest-<env>`) |
| **push** | Mac | host `docker push` | Upload that tag to GHCR (simple retries on fail) |
| **rollout** | pre-prod/prod host | Kamal `deploy --skip-push` | Server **pulls** image from GHCR and **replaces** web+job |

Same path Kamal expects: registry image → pull on host → new containers.  
**Build/push do not use Kamal.** Kamal (via `ghcr.io/basecamp/kamal` + Docker socket) is only for server steps (`config`, `rollout`).

Push retries: up to 5 by default (`--push-retries N`, or `BUILD_PUSH_MAX_ATTEMPTS` / `BUILD_PUSH_RETRY_SLEEP`). Keep `"max-concurrent-uploads": 1` in `~/.docker/daemon.json` if GHCR stalls.

Safe defaults: clean git SHA as image tag, log to `log/deploy/`, wizard pauses on.  
GHCR **login is auto-skipped** when Docker already has `ghcr.io` credentials (use `--force-login` to re-auth, `--skip-login` to never login).

**Hard rule (checked at the start):** shipping actions need a **clean** git tree.

To try **uncommitted** changes on **pre-prod only** (not production):

```bash
script/gs-deploy --allow-dirty
# then pick pre-prod → wizard, build, push, or rollout
```

`--allow-dirty` is **ignored / refused for production** — prod always requires a clean working tree.
Other entry flags (optional): `--version TAG`, `--yes`, `--skip-login`, `--no-log`, `--push-retries N`.

All Docker/Kamal output is streamed to the terminal and tee’d under `log/deploy/`.

After deploy, menu action **verify** SSHes to the app host and runs the suite inside the web container (see `deploy_verify/README.md`).

### Pre-prod deploy_verify auth/CRUD (optional but recommended)

The pre-prod suite can sign in and create/update a symbolset when these secrets exist:

- `DEPLOY_VERIFY_USER_EMAIL`
- `DEPLOY_VERIFY_USER_PASSWORD`

Put them in `.kamal/secrets.pre-prod` (see `secrets.example`). They are listed under `env.secret` in `config/deploy.pre-prod.yml`, so the **web** container gets them on the next rollout. `script/gs-deploy` **verify** also loads secrets and passes them into `docker exec` so CRUD runs even before the next container recreate.

Create a dedicated pre-prod Devise user with the same email/password (not a personal account). Do **not** configure these on production.

## First-time only (manual)

```bash
# accessory DB first (optional separate step)
kamal accessory boot db -d pre-prod
kamal setup -d pre-prod    # installs kamal-proxy etc. — CHANGES SERVER
```

**Do not run setup/deploy until registry, secrets, and image name are real.**
