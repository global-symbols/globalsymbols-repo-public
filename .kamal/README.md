# Kamal secrets (local only)

1. Copy examples and fill values (do not commit):

```bash
cp .kamal/secrets.example .kamal/secrets-common
cp .kamal/secrets.example .kamal/secrets.pre-prod
# edit both files
```

2. Set `image:` and registry in `config/deploy.yml` to a registry you control.

3. Install Kamal (once):

```bash
gem install kamal
# or: bundle add kamal --group development && bundle install
```

4. Validate config **without** touching the server:

```bash
kamal config -d pre-prod
kamal envify -d pre-prod   # only if using that workflow
```

5. When ready to touch the server (explicit decision):

```bash
# accessory DB first (optional separate step)
kamal accessory boot db -d pre-prod

# then app (first time may need setup)
kamal setup -d pre-prod    # installs kamal-proxy etc. — CHANGES SERVER
kamal deploy -d pre-prod   # CHANGES SERVER
```

**Do not run setup/deploy until registry, secrets, and image name are real.**
