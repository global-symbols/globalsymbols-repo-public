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

Ship is split into two actions (wizard runs both, with a pause between):

| Action | Where | Kamal | Server change? |
|--------|--------|--------|----------------|
| **build-push** | Mac | `kamal build push` | No — only build + push to GHCR |
| **rollout** | pre-prod/prod host | `kamal deploy --skip-push` | Yes — pull image, restart web+job |

Safe defaults: clean git SHA as image tag, log to `log/deploy/`, wizard pauses on.  
GHCR **login is auto-skipped** when Docker already has `ghcr.io` credentials (use `--force-login` to re-auth, `--skip-login` to never login).

**Hard rule (checked at the start):** shipping actions need a **clean** git tree.

To try **uncommitted** changes on **pre-prod only** (not production):

```bash
script/gs-deploy --allow-dirty
# then pick pre-prod → wizard or deploy
```

`--allow-dirty` is **ignored / refused for production** — prod always requires a clean working tree.
Other entry flags (optional): `--version TAG`, `--yes`, `--skip-login`, `--no-log`.

All Docker/Kamal output is streamed to the terminal and tee’d under `log/deploy/`.

Kamal itself runs **inside Docker** (`ruby:3.2.11-bookworm` + `kamal` gem) so you do not need a host Ruby install.

After deploy, run the product suite **on the app server** (see `hint-verify` and `deploy_verify/README.md`).

## First-time only (manual)

```bash
# accessory DB first (optional separate step)
# via Dockerized kamal, or once you have kamal available:
kamal accessory boot db -d pre-prod
kamal setup -d pre-prod    # installs kamal-proxy etc. — CHANGES SERVER
```

**Do not run setup/deploy until registry, secrets, and image name are real.**
