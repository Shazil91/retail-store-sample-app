# Implementation Plan: GitHub Actions CI/CD Pipeline

## Overview

Implement the CI/CD pipeline in two layers: first, extract all testable logic into `scripts/ci/helpers.sh` (pure Bash functions), then wire those helpers into the GitHub Actions workflow at `.github/workflows/ci-cd.yml`. Property-based and unit tests are written with [Bats](https://github.com/bats-core/bats-core) and live in `scripts/ci/tests/`. The workflow YAML is validated with static smoke tests.

## Tasks

- [ ] 1. Create the CI helper script scaffold
  - Create `scripts/ci/helpers.sh` with a file header, `set -euo pipefail`, and empty function stubs for: `detect_changed_services`, `derive_image_tag`, `build_ecr_uri`, `patch_helm_values`, `generate_commit_message`, `write_job_summary`
  - Create `scripts/ci/tests/` directory and add a `helpers.bats` test file that sources `scripts/ci/helpers.sh` and contains placeholder `@test` blocks for each function
  - Make `helpers.sh` executable (`chmod +x`)
  - _Requirements: 2.1, 3.3, 5.4, 6.1, 6.2, 6.3, 7.1_

- [ ] 2. Implement `detect_changed_services`
  - [ ] 2.1 Implement `detect_changed_services` in `scripts/ci/helpers.sh`
    - Accept a newline-separated list of changed file paths on stdin (or as a variable)
    - Test each path against the prefixes `src/cart/`, `src/catalog/`, `src/orders/`
    - Print a JSON string of the form `{"service":["cart","orders"]}` (alphabetically sorted, deduplicated); print `{"service":[]}` when no service matches
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [ ]* 2.2 Write property test for `detect_changed_services` (Property 1)
    - **Property 1: Change Detection Correctness**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4**
    - Generate random file path lists using a Bats helper loop (≥100 iterations); assert the output matrix contains a service if and only if at least one path has that service's prefix
    - Tag: `# Feature: github-actions-cicd, Property 1: Change Detection Correctness`

  - [ ]* 2.3 Write unit tests for `detect_changed_services`
    - Test: empty input → `{"service":[]}`
    - Test: only `src/cart/Dockerfile` changed → `{"service":["cart"]}`
    - Test: paths under `src/app/` (umbrella chart, no Dockerfile) → `{"service":[]}`
    - Test: paths under all three services → `{"service":["cart","catalog","orders"]}`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [ ] 3. Implement `derive_image_tag`
  - [ ] 3.1 Implement `derive_image_tag` in `scripts/ci/helpers.sh`
    - Accept a full 40-character Git SHA as the first argument
    - Print the first 7 characters of the SHA
    - _Requirements: 3.3_

  - [ ]* 3.2 Write property test for `derive_image_tag` (Property 2)
    - **Property 2: Image Tag Derivation**
    - **Validates: Requirements 3.3**
    - Generate random 40-char lowercase hex strings (≥100 iterations); assert output is exactly 7 chars and is a prefix of the input
    - Tag: `# Feature: github-actions-cicd, Property 2: Image Tag Derivation`

- [ ] 4. Implement `build_ecr_uri`
  - [ ] 4.1 Implement `build_ecr_uri` in `scripts/ci/helpers.sh`
    - Accept three arguments: `account_id`, `region`, `service_name`
    - Print `<account_id>.dkr.ecr.<region>.amazonaws.com/retail-store-sample-<service_name>`
    - _Requirements: 5.4_

  - [ ]* 4.2 Write property test for `build_ecr_uri` (Property 3)
    - **Property 3: ECR Repository URI Construction**
    - **Validates: Requirements 5.4**
    - Generate random 12-digit account IDs, region strings, and service names (≥100 iterations); assert the output matches the exact URI pattern
    - Tag: `# Feature: github-actions-cicd, Property 3: ECR Repository URI Construction`

- [ ] 5. Implement `patch_helm_values`
  - [ ] 5.1 Implement `patch_helm_values` in `scripts/ci/helpers.sh`
    - Accept three arguments: `values_yaml_path`, `new_tag`, `new_repository`
    - Use `yq e '.image.tag = strenv(NEW_TAG) | .image.repository = strenv(NEW_REPO)' -i` to patch the file in-place
    - Preserve all other fields unchanged
    - _Requirements: 6.1, 6.2_

  - [ ]* 5.2 Write property test for `patch_helm_values` (Property 4)
    - **Property 4: Helm Values Patch Preserves Structure**
    - **Validates: Requirements 6.1, 6.2**
    - Generate random `values.yaml` content with arbitrary extra fields, random tag strings, and random ECR URIs (≥100 iterations); assert `image.tag` and `image.repository` equal the new values and all other top-level keys are unchanged
    - Tag: `# Feature: github-actions-cicd, Property 4: Helm Values Patch Preserves Structure`

  - [ ]* 5.3 Write unit tests for `patch_helm_values`
    - Test: patch `src/cart/chart/values.yaml` fixture → `image.tag` and `image.repository` updated, `replicaCount` and other fields unchanged
    - Test: patch with a tag containing only hex chars → no YAML parse errors
    - _Requirements: 6.1, 6.2_

- [ ] 6. Implement `generate_commit_message`
  - [ ] 6.1 Implement `generate_commit_message` in `scripts/ci/helpers.sh`
    - Accept a comma-separated (or space-separated) list of service names and an image tag as arguments
    - Print `chore: update <services> image tag to <tag> [skip ci]`
    - When only one service: `chore: update cart image tag to a1b2c3d [skip ci]`
    - When multiple services: `chore: update cart,orders image tag to a1b2c3d [skip ci]`
    - _Requirements: 6.3, 6.4_

  - [ ]* 6.2 Write property test for `generate_commit_message` (Property 5)
    - **Property 5: Commit Message Format**
    - **Validates: Requirements 6.3, 6.4**
    - Generate random non-empty service name lists and random tag strings (≥100 iterations); assert message starts with `chore: update`, contains all service names, contains the tag, and ends with `[skip ci]`
    - Tag: `# Feature: github-actions-cicd, Property 5: Commit Message Format`

- [ ] 7. Implement `write_job_summary`
  - [ ] 7.1 Implement `write_job_summary` in `scripts/ci/helpers.sh`
    - Accept a list of service outcome records (service name, image tag or `—`, ECR URI or `—`, status: `built`/`pushed`/`skipped`)
    - Append a Markdown table to `$GITHUB_STEP_SUMMARY` (or a provided file path for testing) with columns: Service, Image Tag, ECR URI, Status
    - Include one row per service; skipped services use `—` for tag and URI
    - _Requirements: 7.1, 7.2_

  - [ ]* 7.2 Write property test for `write_job_summary` (Property 7)
    - **Property 7: Job Summary Completeness**
    - **Validates: Requirements 7.1, 7.2**
    - Generate random lists of 1–3 service outcome records (≥100 iterations); assert the output contains exactly one row per service, each row includes the service name, tag (or `—`), URI (or `—`), and status
    - Tag: `# Feature: github-actions-cicd, Property 7: Job Summary Completeness`

  - [ ]* 7.3 Write unit tests for `write_job_summary`
    - Test: all three services built and pushed → three rows, all with real tags and URIs
    - Test: one service skipped → that row shows `—` for tag and URI with status `skipped`
    - _Requirements: 7.1, 7.2_

- [ ] 8. Checkpoint — Verify helper script tests pass
  - Ensure all Bats tests in `scripts/ci/tests/helpers.bats` pass, ask the user if questions arise.

- [ ] 9. Create the GitHub Actions workflow file
  - [x] 9.1 Create `.github/workflows/ci-cd.yml` with workflow-level metadata
    - Set `name: CI/CD Pipeline`
    - Add `on:` block with `push: branches: [main]`, `pull_request: branches: [main]`, and `workflow_dispatch:`
    - Set `permissions:` block: `contents: write`, `id-token: write`, `pull-requests: read`
    - _Requirements: 1.1, 1.2, 1.3, 8.2_

  - [x] 9.2 Add the `detect-changes` job to `.github/workflows/ci-cd.yml`
    - Run on `ubuntu-latest`
    - Check out the repository (pinned SHA for `actions/checkout`)
    - Run `git diff --name-only ${{ github.event.before }} ${{ github.sha }}` (use merge-base on PRs) and pipe to `scripts/ci/helpers.sh detect_changed_services`
    - Set job output `matrix` from the JSON result
    - Write a summary row for each service with status `skipped` when not in the matrix
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 7.2_

  - [x] 9.3 Add the `build-and-push` matrix job to `.github/workflows/ci-cd.yml`
    - Add `needs: detect-changes` and `if: needs.detect-changes.outputs.matrix != '{"service":[]}'`
    - Set `strategy.matrix` from `${{ fromJson(needs.detect-changes.outputs.matrix) }}`
    - Check out the repository (pinned SHA)
    - Authenticate to AWS via OIDC using `aws-actions/configure-aws-credentials` (pinned SHA), reading `AWS_ROLE_ARN` from secrets and `AWS_REGION` from vars
    - Log in to ECR using `aws-actions/amazon-ecr-login` (pinned SHA)
    - Build the Docker image using `docker/build-push-action` (pinned SHA) with context `src/${{ matrix.service }}/`, Dockerfile `src/${{ matrix.service }}/Dockerfile`, GitHub Actions cache (`cache-from`/`cache-to`), tags for short SHA and `latest`
    - Add `if: github.event_name != 'pull_request'` condition on the push step
    - Set job outputs `image_tag` and `ecr_uri` using `scripts/ci/helpers.sh`
    - Append a summary row via `write_job_summary`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3, 5.5, 5.6, 7.1, 8.1, 8.2_

  - [x] 9.4 Add the `update-helm-values` job to `.github/workflows/ci-cd.yml`
    - Add `needs: build-and-push` and `if: github.event_name != 'pull_request'`
    - Check out the repository using `actions/checkout` with `token: ${{ secrets.GITHUB_TOKEN }}` and `fetch-depth: 0`
    - Configure git user name and email for the commit
    - For each service in the matrix, call `patch_helm_values` with the ECR URI and image tag from `build-and-push` outputs
    - Stage all modified `values.yaml` files with `git add`
    - Call `generate_commit_message` and commit with the result
    - Implement the retry push loop (up to 3 attempts with `git pull --rebase origin main` on conflict) as specified in the design
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

- [x] 10. Write workflow YAML smoke tests
  - [x] 10.1 Create `scripts/ci/tests/workflow-smoke.bats` with static analysis tests
    - Parse `.github/workflows/ci-cd.yml` using `yq` within Bats tests
    - Assert trigger block contains `push.branches: [main]`, `pull_request.branches: [main]`, and `workflow_dispatch`
    - Assert `permissions` block contains `contents: write`, `id-token: write`, `pull-requests: read`
    - Assert push and commit steps have `if: github.event_name != 'pull_request'` conditions
    - Assert `aws-actions/configure-aws-credentials` step uses `role-to-assume: ${{ secrets.AWS_ROLE_ARN }}`
    - Assert `aws-actions/amazon-ecr-login` step is present in the build job
    - _Requirements: 1.1, 1.2, 1.3, 4.1, 4.2, 5.6, 6.7, 8.2_

  - [ ]* 10.2 Write property test for action SHA pinning (Property 8)
    - **Property 8: Action SHA Pinning**
    - **Validates: Requirements 8.1**
    - Parse all `uses:` lines from `.github/workflows/ci-cd.yml`; for each reference assert the `@<ref>` component is a 40-character lowercase hexadecimal string
    - Tag: `# Feature: github-actions-cicd, Property 8: Action SHA Pinning`

- [ ] 11. Final checkpoint — Ensure all tests pass
  - Run `bats scripts/ci/tests/` and confirm all tests pass; ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at logical boundaries
- Property tests validate universal correctness properties (≥100 iterations each per design spec)
- Unit tests validate specific examples and edge cases
- The `scripts/ci/helpers.sh` functions are designed to be sourced or called directly, enabling isolated Bats testing without AWS credentials
- `yq` (v4+) must be available in the CI runner for `patch_helm_values`; the smoke tests also rely on `yq` for YAML parsing
