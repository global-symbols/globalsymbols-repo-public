# =============================================================================
# Deploy image — used for BOTH pre-prod and production (Kamal).
# Environment differences (RAILS_ENV, Redis DBs, DATABASE_HOST, secrets) come
# from Kamal destinations / container env, not from separate images.
#
# Local development uses Dockerfile.dev + docker-compose.yml (gitignored).
#
# Note: no "# syntax=docker/dockerfile:1" — that forces a Docker Hub pull of
# the BuildKit frontend before any layer work and fails hard when Hub is
# unreachable. Multi-stage + COPY --from work with the built-in parser.
# =============================================================================

ARG RUBY_VERSION=3.2.11
FROM docker.io/library/ruby:${RUBY_VERSION}-bookworm AS base

WORKDIR /rails

# Runtime packages (ImageMagick for MiniMagick / CarrierWave; MySQL client lib;
# Node for ExecJS/terser at boot — assets are precompiled, but terser still loads ExecJS)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      default-mysql-client \
      default-libmysqlclient-dev \
      imagemagick \
      libyaml-0-2 \
      shared-mime-info \
      ca-certificates \
      fonts-liberation \
      nodejs && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_LOG_TO_STDOUT="1" \
    RAILS_SERVE_STATIC_FILES="true" \
    PATH="/rails/bin:${PATH}"

# -----------------------------------------------------------------------------
# build: install gems + precompile assets
# -----------------------------------------------------------------------------
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libffi-dev \
      libyaml-dev \
      nodejs \
      pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./

ARG BUNDLER_VERSION=2.5.23
RUN gem install bundler -v "${BUNDLER_VERSION}" && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY . .

# Dummy values only for image build (assets:precompile boots Rails and
# production initializers that require ENV). Real secrets come from Kamal at runtime.
#
# Note: on Docker Desktop, this step can *appear* stuck after the last
# "Writing …/public/assets/…" lines (near grape_swagger). A healthy run
# finishes assets:precompile in ~10–30s total; if log is frozen >2–3 min
# with 0% CPU, interrupt and retry — gs-deploy retries only after a failed
# exit, not mid-hang. The echo below proves Rails finished vs Docker I/O hang.
RUN SECRET_KEY_BASE="dummy_assets_precompile_key_not_for_runtime" \
    REDIS_IP="127.0.0.1" \
    REDIS_PASSWORD="dummy" \
    REDIS_CACHE_DB="0" \
    GS_DATABASE_PASSWORD="dummy" \
    DIRECTUS_URL="http://127.0.0.1:8055" \
    DIRECTUS_TOKEN_CMS="dummy" \
    DIRECTUS_WEBHOOK_SECRET="dummy" \
    ./bin/rails assets:precompile && \
    echo "=== assets:precompile finished OK ===" && \
    ls public/assets | wc -l

# -----------------------------------------------------------------------------
# final: runtime image
# -----------------------------------------------------------------------------
FROM base

# Required by Kamal image checks
LABEL service="gs-repo"

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p log tmp tmp/pids tmp/cache tmp/sockets storage public/uploads && \
    chown -R rails:rails db log tmp storage public

USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Kamal / kamal-proxy expect the app to listen on PORT (default 3000).
EXPOSE 3000

# Default process = web. Sidekiq overrides command in Kamal (role: job).
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
