#!/usr/bin/env bats
# Smoke tests for .github/workflows/ci-cd.yml
# These tests use yq (v4+) to parse the workflow YAML and assert structural
# properties required by the spec.
#
# Requirements: 1.1, 1.2, 1.3, 4.1, 4.2, 5.6, 6.7, 8.2

# ---------------------------------------------------------------------------
# Resolve the workflow file path relative to the repo root.
# Bats may be invoked from any directory; BATS_TEST_DIRNAME is the directory
# that contains this test file (scripts/ci/tests/).  The repo root is two
# levels up.
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
WORKFLOW_FILE="${REPO_ROOT}/.github/workflows/ci-cd.yml"

setup() {
  # Fail fast if the workflow file does not exist.
  if [ ! -f "$WORKFLOW_FILE" ]; then
    echo "Workflow file not found: $WORKFLOW_FILE" >&2
    return 1
  fi
  # Fail fast if yq is not available.
  if ! command -v yq &>/dev/null; then
    echo "yq (v4+) is required but not found in PATH" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Helper: assert yq exits 0 and produces non-empty output
# ---------------------------------------------------------------------------
assert_yq_nonempty() {
  local result
  result=$(yq "$1" "$WORKFLOW_FILE")
  [ -n "$result" ] && [ "$result" != "null" ]
}

# ===========================================================================
# Trigger block (Requirements 1.1, 1.2, 1.3)
# ===========================================================================

@test "trigger: push.branches contains 'main'" {
  # Requirement 1.1 — workflow runs on push to main
  result=$(yq '.on.push.branches[0]' "$WORKFLOW_FILE")
  [ "$result" = "main" ]
}

@test "trigger: pull_request.branches contains 'main'" {
  # Requirement 1.2 — workflow runs on pull_request targeting main
  result=$(yq '.on.pull_request.branches[0]' "$WORKFLOW_FILE")
  [ "$result" = "main" ]
}

@test "trigger: workflow_dispatch is present" {
  # Requirement 1.3 — workflow supports manual dispatch.
  # yq returns "null" when the key is absent.  We check that the key exists
  # and is not null (an empty workflow_dispatch block is represented as null
  # in YAML but the key itself is present).
  result=$(yq '.on | has("workflow_dispatch")' "$WORKFLOW_FILE")
  [ "$result" = "true" ]
}

# ===========================================================================
# Permissions block (Requirement 8.2)
# ===========================================================================

@test "permissions: contents is 'write'" {
  # Requirement 8.2 — minimum permissions; contents:write needed for Helm commit
  result=$(yq '.permissions.contents' "$WORKFLOW_FILE")
  [ "$result" = "write" ]
}

@test "permissions: id-token is 'write'" {
  # Requirement 8.2 — id-token:write needed for OIDC federation
  result=$(yq '.permissions.id-token' "$WORKFLOW_FILE")
  [ "$result" = "write" ]
}

@test "permissions: pull-requests is 'read'" {
  # Requirement 8.2 — pull-requests:read needed for PR metadata
  result=$(yq '.permissions.pull-requests' "$WORKFLOW_FILE")
  [ "$result" = "read" ]
}

# ===========================================================================
# Push step skipped on pull_request (Requirements 5.6)
# ===========================================================================

@test "build-and-push: docker push input is conditioned on non-pull_request event" {
  # Requirement 5.6 — images must NOT be pushed to ECR on pull_request events.
  # The build-push-action step uses `push: ${{ github.event_name != 'pull_request' }}`
  # to gate the push.
  result=$(yq '.jobs.build-and-push.steps[] | select(.uses != null) | select(.uses | test("docker/build-push-action")) | .with.push' "$WORKFLOW_FILE")
  [ "$result" = "\${{ github.event_name != 'pull_request' }}" ]
}

# ===========================================================================
# Helm commit/push skipped on pull_request (Requirement 6.7)
# ===========================================================================

@test "update-helm-values job: if condition excludes pull_request events" {
  # Requirement 6.7 — the Helm values commit job must not run on pull requests.
  # The job-level `if:` expression must contain the guard.
  result=$(yq '.jobs.update-helm-values.if' "$WORKFLOW_FILE")
  [[ "$result" == *"github.event_name != 'pull_request'"* ]]
}

# ===========================================================================
# AWS OIDC authentication (Requirements 4.1, 4.2)
# ===========================================================================

@test "build-and-push: configure-aws-credentials step uses role-to-assume from secrets.AWS_ROLE_ARN" {
  # Requirement 4.1 — OIDC role assumption; no long-lived credentials stored.
  # Requirement 4.2 — role ARN must come from the AWS_ROLE_ARN secret.
  result=$(yq '.jobs.build-and-push.steps[] | select(.uses != null) | select(.uses | test("aws-actions/configure-aws-credentials")) | .with.role-to-assume' "$WORKFLOW_FILE")
  [ "$result" = "\${{ secrets.AWS_ROLE_ARN }}" ]
}

@test "update-helm-values: configure-aws-credentials step uses role-to-assume from secrets.AWS_ROLE_ARN" {
  # Requirement 4.1, 4.2 — same OIDC guard applies in the Helm update job.
  result=$(yq '.jobs.update-helm-values.steps[] | select(.uses != null) | select(.uses | test("aws-actions/configure-aws-credentials")) | .with.role-to-assume' "$WORKFLOW_FILE")
  [ "$result" = "\${{ secrets.AWS_ROLE_ARN }}" ]
}

# ===========================================================================
# ECR login step present in build-and-push (Requirement 5.1)
# ===========================================================================

@test "build-and-push: amazon-ecr-login step is present" {
  # Requirement 5.1 — the build job must log in to ECR before pushing images.
  result=$(yq '.jobs.build-and-push.steps[] | select(.uses != null) | select(.uses | test("aws-actions/amazon-ecr-login")) | .uses' "$WORKFLOW_FILE")
  [[ "$result" == *"aws-actions/amazon-ecr-login"* ]]
}
