# Implementation Plan: GitHub Actions CI/CD Pipeline

## Overview

Create a single `.github/workflows/ci.yml` file that implements the full CI/CD pipeline: change detection via `dorny/paths-filter@v3`, per-service Docker image builds pushed to ECR, and per-service Helm chart `values.yaml` updates committed back to `main`. All five service chains (`cart`, `catalog`, `orders`, `checkout`, `ui`) are independent so a failure in one does not block the others.

## Tasks

- [x] 1. Create the workflow file skeleton with triggers and permissions
  - Create `.github/workflows/ci.yml`
  - Add `on:` block triggering on `push` and `pull_request` to `main`
  - Add top-level `permissions:` block with `contents: write` and `id-token: write`
  - _Requirements: 8.1, 8.2, 9.1, 9.2, 9.3_

- [x] 2. Implement the `detect-changes` job
  - Add the `detect-changes` job using `dorny/paths-filter@v3`
  - Define path filters for all five services: `src/cart/**`, `src/catalog/**`, `src/orders/**`, `src/checkout/**`, `src/ui/**`
  - Declare job-level `outputs:` that expose each filter result (`cart`, `catalog`, `orders`, `checkout`, `ui`)
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 3. Implement the five `build-<service>` jobs
  - [x] 3.1 Implement `build-cart`
    - Add `needs: detect-changes` and `if: needs.detect-changes.outputs.cart == 'true'`
    - Add step: `actions/checkout@v4`
    - Add step: `aws-actions/configure-aws-credentials@v4` using `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_REGION` secrets
    - Add step: `aws-actions/amazon-ecr-login@v2`, capturing the `registry` output
    - Add step: derive `IMAGE_TAG` as `${GITHUB_SHA::7}`, then `docker build -t <registry>/retail-store-sample-cart:$IMAGE_TAG src/cart/`
    - Add step: `docker push` the SHA-tagged image
    - Add step: `docker push` the `latest`-tagged image
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3, 5.4_

  - [x] 3.2 Implement `build-catalog`
    - Repeat the same structure as `build-cart` with service name `catalog`
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3, 5.4_

  - [x] 3.3 Implement `build-orders`
    - Repeat the same structure as `build-cart` with service name `orders`
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3, 5.4_

  - [x] 3.4 Implement `build-checkout`
    - Repeat the same structure as `build-cart` with service name `checkout`
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3, 5.4_

  - [x] 3.5 Implement `build-ui`
    - Repeat the same structure as `build-cart` with service name `ui`
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3, 5.4_

- [x] 4. Checkpoint — verify build jobs are well-formed
  - Ensure all five `build-<service>` jobs are syntactically correct YAML
  - Ensure all jobs share the same step structure and only differ in the service name
  - Ensure all jobs pass, ask the user if questions arise.

- [x] 5. Implement the five `update-helm-<service>` jobs
  - [x] 5.1 Implement `update-helm-cart`
    - Add `needs: build-cart` and `if: github.event_name == 'push'`
    - Add step: `actions/checkout@v4`
    - Add step: derive `IMAGE_TAG` as `${GITHUB_SHA::7}` and `ECR_REGISTRY` from the build job output (or re-derive from secrets)
    - Add step: run `sed -i "s|  tag:.*|  tag: \"${IMAGE_TAG}\"|" src/cart/chart/values.yaml`
    - Add step: run `sed -i "s|  repository:.*|  repository: \"${ECR_REGISTRY}/retail-store-sample-cart\"|" src/cart/chart/values.yaml`
    - Add step: verify the substitution succeeded with `git diff --exit-code src/cart/chart/values.yaml` negated (fail if no change was made)
    - Add step: configure git user as `github-actions[bot]`
    - Add step: `git commit -am "ci: update cart image tag to ${IMAGE_TAG} [skip ci]"`
    - Add step: `git push origin main` using `GITHUB_TOKEN`
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 8.3, 8.4_

  - [x] 5.2 Implement `update-helm-catalog`
    - Repeat the same structure as `update-helm-cart` with service name `catalog` and `needs: build-catalog`
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 8.3, 8.4_

  - [x] 5.3 Implement `update-helm-orders`
    - Repeat the same structure as `update-helm-cart` with service name `orders` and `needs: build-orders`
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 8.3, 8.4_

  - [x] 5.4 Implement `update-helm-checkout`
    - Repeat the same structure as `update-helm-cart` with service name `checkout` and `needs: build-checkout`
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 8.3, 8.4_

  - [x] 5.5 Implement `update-helm-ui`
    - Repeat the same structure as `update-helm-cart` with service name `ui` and `needs: build-ui`
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 8.3, 8.4_

- [ ] 6. Validate the complete workflow file with `actionlint`
  - Run `actionlint .github/workflows/ci.yml` and fix any reported errors
  - Confirm no invalid action references, expression syntax errors, or missing required inputs
  - _Requirements: 1.1–1.4, 2.1–2.3, 3.1–3.3, 4.1–4.5, 5.1–5.4, 6.1–6.6, 7.1–7.3, 8.1–8.4, 9.1–9.3_

- [ ] 7. Final checkpoint — Ensure all tests pass
  - Ensure `actionlint` reports zero errors on the workflow file
  - Verify the job DAG matches the architecture diagram: `detect-changes → build-<service> → update-helm-<service>` for each of the five services
  - Verify `update-helm-*` jobs all carry `if: github.event_name == 'push'`
  - Verify all Helm update commit messages include `[skip ci]`
  - Ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- No property-based tests are included — the design document explicitly identifies this feature as declarative YAML configuration where PBT is not applicable; correctness is validated through `actionlint` static analysis and example-based integration tests
- The `update-helm-*` jobs re-derive `IMAGE_TAG` from `${{ github.sha }}` rather than passing it between jobs, keeping each job self-contained
- All five service chains are fully independent; a failure in one does not affect the others (Requirement 7.3)
