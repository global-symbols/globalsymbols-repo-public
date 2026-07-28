#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

COMPOSE_PROJECT="${COMPOSE_PROJECT:-gs-s3-setup}"
REPORT_DIR="${REPORT_DIR:-local_rails_upgrade}"
BACKUP=false
REPORT=false
ARGS=()

usage() {
  echo "Usage: script/run_tests.sh [options] [rails test arguments...]"
  echo ""
  echo "Options:"
  echo "  --backup, -b    Dump gs-repo-dev to tmp/db_backups/ before running tests"
  echo "  --report, -r    Write a markdown report and log to ${REPORT_DIR}/"
  echo "  --help, -h      Show this help"
  echo ""
  echo "Examples:"
  echo "  script/run_tests.sh --backup --report"
  echo "  script/run_tests.sh --report test/integration"
  echo "  script/run_tests.sh test/integration/global_symbols_v1_test.rb"
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --backup|-b)
      BACKUP=true
      shift
      ;;
    --report|-r)
      REPORT=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#ARGS[@]} -eq 0 ]]; then
  ARGS=(test/integration)
fi

cd "$REPO_ROOT"

BACKUP_FILE=""
if $BACKUP; then
  "$SCRIPT_DIR/backup_dev_db.sh"
  if [[ -f tmp/db_backups/LATEST ]]; then
    BACKUP_FILE="$(cat tmp/db_backups/LATEST)"
  fi
fi

RUN_STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE=""
REPORT_FILE=""
COMMAND_PARTS=("script/run_tests.sh")
$BACKUP && COMMAND_PARTS+=("--backup")
$REPORT && COMMAND_PARTS+=("--report")
COMMAND_PARTS+=("${ARGS[@]}")
COMMAND_LINE="${COMMAND_PARTS[*]}"

if $REPORT; then
  mkdir -p "$REPORT_DIR"
  LOG_FILE="$REPORT_DIR/test_run_${RUN_STAMP}.log"
  REPORT_FILE="$REPORT_DIR/test_run_${RUN_STAMP}.md"
fi

# Shared dev database: mark metadata for test runs without db:test:prepare.
docker compose -p "$COMPOSE_PROJECT" exec -e RAILS_ENV=test web \
  bin/rails db:environment:set RAILS_ENV=test

TEST_ARGS=("${ARGS[@]}")
if $REPORT; then
  # Ensure skip reasons are captured in the log.
  has_verbose=false
  for arg in "${TEST_ARGS[@]}"; do
    if [[ "$arg" == "--verbose" || "$arg" == "-v" ]]; then
      has_verbose=true
      break
    fi
  done
  $has_verbose || TEST_ARGS+=(--verbose)
fi

if $REPORT; then
  set +e
  docker compose -p "$COMPOSE_PROJECT" exec -e RAILS_ENV=test web \
    bin/rails test "${TEST_ARGS[@]}" 2>&1 | tee "$LOG_FILE"
  TEST_EXIT=${PIPESTATUS[0]}
  set -e
else
  docker compose -p "$COMPOSE_PROJECT" exec -e RAILS_ENV=test web \
    bin/rails test "${TEST_ARGS[@]}"
  TEST_EXIT=$?
fi

docker compose -p "$COMPOSE_PROJECT" exec -e RAILS_ENV=development web \
  bin/rails db:environment:set RAILS_ENV=development

if $REPORT; then
  "$SCRIPT_DIR/generate_test_report.sh" \
    "$LOG_FILE" \
    "$REPORT_FILE" \
    "$TEST_EXIT" \
    "$COMMAND_LINE" \
    "$BACKUP_FILE"
fi

exit $TEST_EXIT