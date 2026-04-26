# Requirements Document

## Introduction

This feature introduces a GitHub Actions CI/CD pipeline for the retail store sample application. The pipeline detects file changes per service/component, builds Docker images, pushes them to Amazon ECR, and updates the `image.tag` field in each service's Helm chart `values.yaml` after a successful push. The pipeline covers five services: `cart` (Java/Spring Boot), `catalog` (Go), `orders` (Java/Spring Boot), `checkout` (Node.js/TypeScript), and `ui` (Java/Spring Boot).

## Glossary

- **Pipeline**: The GitHub Actions workflow defined in `.github/workflows/`.
- **Service**: One of the five application components — `cart`, `catalog`, `orders`, `checkout`, or `ui` — each located under `src/<service>/`.
- **ECR**: Amazon Elastic Container Registry, the target Docker image registry.
- **ECR_Repository**: The per-service ECR repository where Docker images are stored, named `retail-store-sample-<service>`.
- **Image_Tag**: The Docker image tag written to `src/<service>/chart/values.yaml` under `image.tag`, used by Helm to deploy the correct image version.
- **Change_Detection**: The process of determining which services have file changes in a given commit or pull request.
- **Build_Job**: The per-service GitHub Actions job that builds and pushes a Docker image.
- **Helm_Update_Job**: The per-service GitHub Actions job that updates `image.tag` in `values.yaml` after a successful image push.
- **AWS_Credentials**: The AWS access key ID and secret access key stored as GitHub Actions secrets, used to authenticate with ECR.
- **Git_Commit**: A commit made by the Pipeline to the repository to persist Helm chart tag updates.

---

## Requirements

### Requirement 1: Per-Service Change Detection

**User Story:** As a developer, I want the pipeline to detect which services have changed, so that only affected services are built and pushed, avoiding unnecessary work.

#### Acceptance Criteria

1. WHEN a push or pull request event targets the `main` branch, THE Pipeline SHALL evaluate file path filters for each service directory (`src/cart/**`, `src/catalog/**`, `src/orders/**`, `src/checkout/**`, `src/ui/**`).
2. WHEN files under `src/<service>/` are modified in a triggering event, THE Pipeline SHALL set a boolean output indicating that the corresponding service has changed.
3. WHEN no files under `src/<service>/` are modified in a triggering event, THE Pipeline SHALL skip the Build_Job and Helm_Update_Job for that service.
4. THE Pipeline SHALL evaluate change detection for all five services independently and in parallel.

---

### Requirement 2: AWS Authentication

**User Story:** As a pipeline operator, I want the pipeline to authenticate with AWS using stored secrets, so that it can push images to ECR without embedding credentials in code.

#### Acceptance Criteria

1. WHEN a Build_Job starts, THE Pipeline SHALL configure AWS credentials using the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` GitHub Actions secrets.
2. THE Pipeline SHALL use the `AWS_REGION` GitHub Actions secret or variable to specify the target AWS region for ECR operations.
3. IF the AWS credentials are invalid or expired, THEN THE Pipeline SHALL fail the Build_Job with a descriptive authentication error and SHALL NOT proceed to image build or push steps.

---

### Requirement 3: ECR Login

**User Story:** As a pipeline operator, I want the pipeline to log in to Amazon ECR before pushing images, so that Docker has the credentials needed to push to the private registry.

#### Acceptance Criteria

1. WHEN AWS credentials are successfully configured, THE Pipeline SHALL authenticate the Docker client with the ECR registry using the AWS CLI `ecr get-login-password` command piped to `docker login`.
2. THE Pipeline SHALL derive the ECR registry URL from the AWS account ID and region in the format `<account-id>.dkr.ecr.<region>.amazonaws.com`.
3. IF the ECR login step fails, THEN THE Pipeline SHALL fail the Build_Job and SHALL NOT proceed to the image build step.

---

### Requirement 4: Docker Image Build

**User Story:** As a developer, I want each changed service to have its Docker image built from its `Dockerfile`, so that the latest code is packaged into a deployable artifact.

#### Acceptance Criteria

1. WHEN a service is detected as changed, THE Build_Job SHALL build a Docker image using the `Dockerfile` located at `src/<service>/Dockerfile`.
2. THE Build_Job SHALL set the Docker build context to `src/<service>/`.
3. THE Build_Job SHALL tag the built image with the full ECR repository URI in the format `<account-id>.dkr.ecr.<region>.amazonaws.com/retail-store-sample-<service>:<image-tag>`.
4. THE Build_Job SHALL derive the Image_Tag from the short SHA of the triggering Git commit (7 characters).
5. IF the Docker build step fails, THEN THE Build_Job SHALL fail and SHALL NOT proceed to the image push step.

---

### Requirement 5: Docker Image Push to ECR

**User Story:** As a developer, I want successfully built images to be pushed to Amazon ECR, so that they are available for deployment.

#### Acceptance Criteria

1. WHEN a Docker image is successfully built, THE Build_Job SHALL push the image to the ECR_Repository for that service.
2. THE Build_Job SHALL also push the same image tagged as `latest` to the ECR_Repository.
3. IF the ECR_Repository for a service does not exist, THEN THE Build_Job SHALL fail with a descriptive error indicating the missing repository.
4. IF the image push step fails, THEN THE Build_Job SHALL fail and SHALL NOT trigger the Helm_Update_Job for that service.

---

### Requirement 6: Helm Chart Image Tag Update

**User Story:** As a developer, I want the Helm chart `values.yaml` for each service to be updated with the new image tag after a successful push, so that the chart reflects the latest deployable image.

#### Acceptance Criteria

1. WHEN a Docker image is successfully pushed to ECR, THE Helm_Update_Job SHALL update the `image.tag` field in `src/<service>/chart/values.yaml` to the Image_Tag used during the build.
2. THE Helm_Update_Job SHALL update the `image.repository` field in `src/<service>/chart/values.yaml` to the full ECR repository URI (without the tag).
3. THE Helm_Update_Job SHALL commit the updated `values.yaml` file to the repository with a commit message in the format `ci: update <service> image tag to <image-tag> [skip ci]`.
4. THE Helm_Update_Job SHALL push the commit to the `main` branch using a GitHub token stored as the `GITHUB_TOKEN` secret.
5. IF the `values.yaml` file for a service does not contain an `image.tag` field, THEN THE Helm_Update_Job SHALL fail with a descriptive error.
6. THE Helm_Update_Job SHALL only run after the corresponding Build_Job completes successfully, using a `needs` dependency.

---

### Requirement 7: Pipeline Concurrency and Isolation

**User Story:** As a developer, I want each service's build and update jobs to run independently, so that a failure in one service does not block other services from completing their pipeline.

#### Acceptance Criteria

1. THE Pipeline SHALL run Build_Jobs for all changed services in parallel, with no cross-service dependencies.
2. THE Pipeline SHALL run each Helm_Update_Job only after its corresponding Build_Job succeeds, and independently of other services' Helm_Update_Jobs.
3. WHEN multiple services change in the same commit, THE Pipeline SHALL complete all independent Build_Jobs and Helm_Update_Jobs without one service's failure blocking another service's jobs.

---

### Requirement 8: Pipeline Trigger Configuration

**User Story:** As a developer, I want the pipeline to trigger on pushes and pull requests to the `main` branch, so that every code change is validated and deployed automatically.

#### Acceptance Criteria

1. THE Pipeline SHALL trigger on `push` events targeting the `main` branch.
2. THE Pipeline SHALL trigger on `pull_request` events targeting the `main` branch.
3. WHEN triggered by a `pull_request` event, THE Pipeline SHALL execute change detection and Build_Jobs but SHALL NOT push commits to the repository (Helm_Update_Job is skipped).
4. THE Pipeline SHALL include a `[skip ci]` string check so that commits made by the Helm_Update_Job do not re-trigger the pipeline.

---

### Requirement 9: Workflow Permissions

**User Story:** As a pipeline operator, I want the workflow to have the minimum required permissions, so that the pipeline follows the principle of least privilege.

#### Acceptance Criteria

1. THE Pipeline SHALL declare `contents: write` permission to allow the Helm_Update_Job to commit and push changes.
2. THE Pipeline SHALL declare `id-token: write` permission to support OIDC-based AWS authentication as an optional upgrade path.
3. THE Pipeline SHALL NOT declare permissions beyond those required for ECR push and repository write operations.
