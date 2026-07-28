#!/usr/bin/env bash
# Generate a markdown test run report from a Minitest log file.
set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "Usage: script/generate_test_report.sh <log_file> <report_file> <exit_code> <command_line> [backup_file]" >&2
  exit 1
fi

LOG_FILE="$1"
REPORT_FILE="$2"
TEST_EXIT="$3"
COMMAND_LINE="$4"
BACKUP_FILE="${5:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_PROJECT="${COMPOSE_PROJECT:-gs-s3-setup}"
INTEGRATION_DIR="$REPO_ROOT/test/integration"

TIMESTAMP_LOCAL="$(date '+%Y-%m-%d %H:%M:%S %Z')"
TIMESTAMP_UTC="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
RUN_STAMP="$(basename "$REPORT_FILE" .md | sed 's/^test_run_//')"

GIT_BRANCH="$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo 'unknown')"
GIT_COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
GIT_SUBJECT="$(git -C "$REPO_ROOT" log -1 --format='%s' 2>/dev/null || echo '')"

RAILS_VERSION="$(docker compose -p "$COMPOSE_PROJECT" exec -T web bin/rails -v 2>/dev/null | tail -1 | awk '{print $2}' || echo 'unknown')"
RUBY_VERSION="$(docker compose -p "$COMPOSE_PROJECT" exec -T web ruby -v 2>/dev/null | head -1 || echo 'unknown')"

SUMMARY_LINE="$(grep -E '^[0-9]+ runs,' "$LOG_FILE" | tail -1 || true)"
RUNS="$(echo "$SUMMARY_LINE" | sed -n 's/^\([0-9]*\) runs.*/\1/p')"
ASSERTIONS="$(echo "$SUMMARY_LINE" | sed -n 's/.*, \([0-9]*\) assertions.*/\1/p')"
FAILURES="$(echo "$SUMMARY_LINE" | sed -n 's/.*, \([0-9]*\) failures.*/\1/p')"
ERRORS="$(echo "$SUMMARY_LINE" | sed -n 's/.*, \([0-9]*\) errors.*/\1/p')"
SKIPS="$(echo "$SUMMARY_LINE" | sed -n 's/.*, \([0-9]*\) skips.*/\1/p')"
DURATION="$(grep -E '^Finished in ' "$LOG_FILE" | tail -1 | sed -n 's/^Finished in \([0-9.]*\)s.*/\1/p')"
SEED="$(grep -E 'Run options:.*--seed' "$LOG_FILE" | tail -1 | sed -n 's/.*--seed \([0-9]*\).*/\1/p' || true)"

if [[ "$TEST_EXIT" -eq 0 && "${FAILURES:-0}" -eq 0 && "${ERRORS:-0}" -eq 0 ]]; then
  RESULT="PASS"
else
  RESULT="FAIL"
fi

BACKUP_SIZE=""
if [[ -n "$BACKUP_FILE" && -f "$REPO_ROOT/$BACKUP_FILE" ]]; then
  BACKUP_SIZE="$(du -h "$REPO_ROOT/$BACKUP_FILE" | awk '{print $1}')"
fi

mkdir -p "$(dirname "$REPORT_FILE")"

{
  echo "# Integration test run report"
  echo
  echo "**Run stamp:** \`test_run_${RUN_STAMP}\`"
  echo "**Result:** ${RESULT}"
  echo
  echo "---"
  echo
  echo "## Run metadata"
  echo
  echo "| Field | Value |"
  echo "|-------|--------|"
  echo "| Timestamp (local) | ${TIMESTAMP_LOCAL} |"
  echo "| Timestamp (UTC) | ${TIMESTAMP_UTC} |"
  echo "| Branch | \`${GIT_BRANCH}\` |"
  echo "| Git commit | \`${GIT_COMMIT}\` — ${GIT_SUBJECT} |"
  echo "| Rails version | ${RAILS_VERSION} |"
  echo "| Ruby version | ${RUBY_VERSION} |"
  echo "| Test framework | Minitest (Rails default) |"
  echo "| Compose project | \`${COMPOSE_PROJECT}\` |"
  echo "| Database | \`gs-repo-dev\` (shared with development) |"
  echo "| Test isolation | Transactional rollback per test |"
  echo "| Command | \`${COMMAND_LINE}\` |"
  echo "| Minitest seed | ${SEED:-unknown} |"
  echo "| Duration | ${DURATION:-unknown}s |"
  echo "| Log file | \`$(basename "$LOG_FILE")\` |"
  echo
  echo "---"
  echo
  echo "## Summary"
  echo
  echo "| Metric | Count |"
  echo "|--------|------:|"
  echo "| Runs | ${RUNS:-0} |"
  echo "| Assertions | ${ASSERTIONS:-0} |"
  echo "| Failures | ${FAILURES:-0} |"
  echo "| Errors | ${ERRORS:-0} |"
  echo "| Skips | ${SKIPS:-0} |"
  echo "| Exit code | ${TEST_EXIT} |"
  echo
  echo "---"
  echo
  echo "## Database backup"
  echo
  if [[ -n "$BACKUP_FILE" ]]; then
    echo "| Field | Value |"
    echo "|-------|--------|"
    echo "| Backup taken | Yes (before test run) |"
    echo "| Path | \`${BACKUP_FILE}\` |"
    echo "| Size | ${BACKUP_SIZE:-unknown} |"
  else
    echo "No backup taken for this run."
  fi
  echo
  echo "---"
  echo
  echo "## Test files"
  echo
  echo "| File | Tests |"
  echo "|------|------:|"

  TOTAL_TESTS=0
  for file in "$INTEGRATION_DIR"/*_test.rb; do
    [[ -f "$file" ]] || continue
    count="$(grep -cE "^[[:space:]]*test '" "$file" || true)"
    TOTAL_TESTS=$((TOTAL_TESTS + count))
    echo "| \`$(basename "$file")\` | ${count} |"
  done
  echo "| **Total** | **${TOTAL_TESTS}** |"
  echo
  echo "---"
  echo
  echo "## Skipped tests"
  echo
  if grep -q '^Skipped:' "$LOG_FILE"; then
    echo "| Test | Reason |"
    echo "|------|--------|"
    awk '
      /^Skipped:/ {
        getline
        line = $0
        sub(/^[[:space:]]+/, "", line)
        sub(/ \[[^]]+\]:$/, "", line)
        test = line
        getline
        reason = $0
        sub(/^[[:space:]]+/, "", reason)
        gsub(/\|/, "\\|", reason)
        printf "| `%s` | %s |\n", test, reason
      }
    ' "$LOG_FILE"
  else
    echo "None."
  fi
  echo
  echo "---"
  echo
  echo "## Tests by file"
  echo

  for file in "$INTEGRATION_DIR"/*_test.rb; do
    [[ -f "$file" ]] || continue
    echo "### \`$(basename "$file")\`"
    echo
    grep -E "^[[:space:]]*test '" "$file" | sed -E "s/^[[:space:]]*test '(.*)'.*$/ - \1/" || true
    echo
  done

  if [[ "${FAILURES:-0}" -gt 0 || "${ERRORS:-0}" -gt 0 ]]; then
    echo "---"
    echo
    echo "## Failures and errors"
    echo
    echo '```'
    grep -A 20 '^Failure:\|^Error:' "$LOG_FILE" || true
    echo '```'
    echo
  fi
} > "$REPORT_FILE"

echo "Report written to ${REPORT_FILE}"