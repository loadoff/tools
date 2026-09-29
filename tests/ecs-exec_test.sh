#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ECS_EXEC="$ROOT/bin/ecs-exec"
MOCK_AWS="$ROOT/tests/mock-aws"
PASS=0
FAIL=0

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local name="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name"
    echo "  missing: $needle"
    echo "  in:      $haystack"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit() {
  local name="$1" expected="$2"
  shift 2
  set +e
  "$@" >/tmp/ecs_exec_out 2>/tmp/ecs_exec_err
  local code=$?
  set -e
  if [[ "$code" -eq "$expected" ]]; then
    echo "PASS: $name (exit $code)"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (exit $code, want $expected)"
    echo "  stdout: $(cat /tmp/ecs_exec_out)"
    echo "  stderr: $(cat /tmp/ecs_exec_err)"
    FAIL=$((FAIL + 1))
  fi
}

chmod +x "$ECS_EXEC" "$MOCK_AWS"

# --- normal: full args dry-run ---
out="$(
  AWS_CLI="$MOCK_AWS" \
  MOCK_AWS_CONTAINERS=app \
  "$ECS_EXEC" \
    --cluster demo \
    --task arn:aws:ecs:ap-northeast-1:123:task/demo/task-1 \
    --container app \
    --region ap-northeast-1 \
    --dry-run
)"
assert_contains "dry-run includes execute-command" "execute-command" "$out"
assert_contains "dry-run includes cluster" "--cluster demo" "$out"
assert_contains "dry-run includes container" "--container app" "$out"
assert_contains "dry-run includes region" "--region ap-northeast-1" "$out"

# --- normal: service resolves task then execute (no dry-run) ---
out="$(
  AWS_CLI="$MOCK_AWS" \
  MOCK_AWS_TASKS="arn:aws:ecs:ap-northeast-1:123:task/demo/task-1" \
  MOCK_AWS_CONTAINERS=app \
  "$ECS_EXEC" \
    --cluster demo \
    --service web \
    --container app \
    --command /bin/bash
)"
assert_contains "execute via service" "MOCK_EXECUTE ecs execute-command" "$out"
assert_contains "execute command flag" "--command /bin/bash" "$out"

# --- abnormal: aws missing ---
assert_exit "aws missing" 1 \
  env AWS_CLI="/nonexistent/aws-bin-$$" "$ECS_EXEC" --cluster demo --task t --container app --dry-run
assert_contains "aws missing message" "AWS CLI not found" "$(cat /tmp/ecs_exec_err)"

# --- abnormal: no running tasks ---
assert_exit "no tasks" 1 \
  env AWS_CLI="$MOCK_AWS" MOCK_AWS_TASKS=EMPTY \
  "$ECS_EXEC" --cluster demo --service web --container app --dry-run
assert_contains "no tasks message" "no RUNNING tasks" "$(cat /tmp/ecs_exec_err)"

# --- abnormal: multi container without --container (non-TTY) ---
assert_exit "multi container needs flag" 1 \
  env AWS_CLI="$MOCK_AWS" MOCK_AWS_CONTAINERS=MULTI \
  "$ECS_EXEC" --cluster demo --task task-1 --dry-run </dev/null
assert_contains "multi container message" "multiple candidates" "$(cat /tmp/ecs_exec_err)"

# --- abnormal: unknown option ---
assert_exit "unknown option" 1 "$ECS_EXEC" --nope
assert_contains "unknown option message" "unknown option" "$(cat /tmp/ecs_exec_err)"

# --- help ---
assert_exit "help" 0 "$ECS_EXEC" --help
assert_contains "help text" "execute-command" "$(cat /tmp/ecs_exec_out)"

echo
echo "Result: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
