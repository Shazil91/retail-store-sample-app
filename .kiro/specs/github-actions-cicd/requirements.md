# Requirements Document

## Introduction

This feature adds a GitHub Actions CI/CD workflow to the retail store sample application — a microservices system composed of `cart` (Java/Spring Boot), `catalog` (Go), and `orders` (Java/Spring Boot) services, each with a Dockerfile and a Helm chart. The workflow automates three concerns: detecting which services have changed on a push, building and pushing Docker images for changed services to Amazon ECR, and updating the `image.tag` value in each service's Helm chart `values.yaml` so that the repository reflects the new image version. The `app` umbrella chart aggregates all service charts and does not have its own Dockerfile.

## Glossary

- **CI_CD_Workflow**: The GitHub Actions workflow defined in `.github/workflows/` that orchestrates the build and release pipeline.
- **Service**: One of the independently deployable components — `cart`, `catalog`, or `orders` — each located under `src/<service>/`.
- **Change_Detector**: The job or step responsible for determining which services have file changes in a given push.
- **Image_Builder**: The job or step responsible for building a Docker image from a service's `Dockerfile`.
- **ECR**: Amazon Elastic Container Registry — the target registry where Docker images are pushed.
- **Helm_Updater**: The job or step responsible for updating `image.tag` in a service's `src/<service>/chart/values.yaml`.
- **Image_Tag**: The Docker image tag derived from the Git SHA of the triggering commit (e.g., `git rev-parse --short HEAD`).
- **Service_Matrix**: A dynamic GitHub Actions matrix constructed from the list of changed services, used to fan out build jobs in parallel.
- **ECR_Repository**: A per-service repository in Amazon ECR named after the service (e.g., `retail-store-sample-cart`).
- **OIDC_Role**: An AWS IAM role assumed by the CI_CD_Workflow via GitHub Actions OIDC federation, granting ECR push and pull permissions without long-lived credentials.

---

## Requirements

### Requirement 1: Workflow Trigger

**User Story:** As a developer, I want the CI/CD workflow to run automatically on pushes to the main branch, so that every merged change is built and released without manual intervention.

#### Acceptance Criteria

1. WHEN a push event targets the `main` branch, THE CI_CD_Workflow SHALL start execution.
2. WHEN a pull request targets the `main` branch, THE CI_CD_Workflow SHALL start execution in a read-only mode that builds images but does not push to ECR or update Helm values.
3. THE CI_CD_Workflow SHALL allow manual triggering via `workflow_dispatch` with no required inputs.

---

### Requirement 2: Per-Service Change Detection

**User Story:** As a developer, I want the workflow to detect which services have changed, so that only affected services are rebuilt and redeployed, reducing build time and unnecessary image churn.

#### Acceptance Criteria

1. WHEN a push occurs, THE Change_Detector SHALL compare the changed file paths against the path prefixes `src/cart/`, `src/catalog/`, and `src/orders/`.
2. WHEN files under `src/<service>/` have changed, THE Change_Detector SHALL mark that service as requiring a build.
3. WHEN no files under a service's path prefix have changed, THE Change_Detector SHALL exclude that service from the Service_Matrix.
4. THE Change_Detector SHALL produce a Service_Matrix containing only the services that require a build.
5. WHEN the Service_Matrix is empty (no services changed), THE CI_CD_Workflow SHALL exit successfully without executing build or update jobs.

---

### Requirement 3: Docker Image Build

**User Story:** As a developer, I want each changed service's Docker image to be built using its Dockerfile, so that the image reflects the latest source code.

#### Acceptance Criteria

1. WHEN a service is included in the Service_Matrix, THE Image_Builder SHALL build the Docker image using the `Dockerfile` located at `src/<service>/Dockerfile`.
2. THE Image_Builder SHALL set the Docker build context to `src/<service>/`.
3. THE Image_Builder SHALL tag the built image with the Image_Tag derived from the short Git SHA of the triggering commit.
4. THE Image_Builder SHALL also tag the built image with `latest`.
5. IF the Docker build step exits with a non-zero status, THEN THE CI_CD_Workflow SHALL fail the job for that service and report the error.
6. THE Image_Builder SHALL use Docker layer caching (e.g., GitHub Actions cache or inline cache) to reduce build time on subsequent runs.

---

### Requirement 4: AWS Authentication

**User Story:** As a platform engineer, I want the workflow to authenticate to AWS using short-lived credentials via OIDC, so that no long-lived AWS access keys are stored as GitHub secrets.

#### Acceptance Criteria

1. THE CI_CD_Workflow SHALL authenticate to AWS by assuming the OIDC_Role using the `aws-actions/configure-aws-credentials` action.
2. THE CI_CD_Workflow SHALL read the OIDC_Role ARN from a GitHub Actions secret named `AWS_ROLE_ARN`.
3. THE CI_CD_Workflow SHALL read the target AWS region from a GitHub Actions variable or secret named `AWS_REGION`.
4. IF AWS authentication fails, THEN THE CI_CD_Workflow SHALL fail immediately and not proceed to image push or Helm update steps.

---

### Requirement 5: Docker Image Push to ECR

**User Story:** As a platform engineer, I want built images pushed to Amazon ECR, so that the EKS cluster can pull them during deployment.

#### Acceptance Criteria

1. WHEN a service image has been successfully built, THE Image_Builder SHALL authenticate to ECR using the `aws-actions/amazon-ecr-login` action.
2. THE Image_Builder SHALL push the image tagged with the Image_Tag to the ECR_Repository for that service.
3. THE Image_Builder SHALL push the `latest` tag to the same ECR_Repository.
4. THE CI_CD_Workflow SHALL derive the ECR_Repository URI from the AWS account ID, region, and a repository name following the pattern `retail-store-sample-<service>`.
5. IF the ECR push step fails, THEN THE CI_CD_Workflow SHALL fail the job for that service and not proceed to the Helm update step for that service.
6. WHEN running on a pull request, THE Image_Builder SHALL skip the ECR push step and only perform the build.

---

### Requirement 6: Helm Chart Image Tag Update

**User Story:** As a developer, I want the workflow to update the `image.tag` field in each service's Helm chart `values.yaml` after a successful image push, so that the chart always references the image that was just built.

#### Acceptance Criteria

1. WHEN an image has been successfully pushed to ECR, THE Helm_Updater SHALL update the `image.tag` field in `src/<service>/chart/values.yaml` to the Image_Tag used during the build.
2. THE Helm_Updater SHALL update the `image.repository` field in `src/<service>/chart/values.yaml` to the full ECR_Repository URI for that service.
3. THE Helm_Updater SHALL commit the updated `values.yaml` file(s) to the `main` branch with a commit message in the format `chore: update <service> image tag to <image-tag> [skip ci]`.
4. THE CI_CD_Workflow SHALL include `[skip ci]` in the commit message to prevent the commit from re-triggering the workflow.
5. IF multiple services are updated in the same workflow run, THE Helm_Updater SHALL batch all `values.yaml` changes into a single commit.
6. IF the git commit or push step fails due to a concurrent commit conflict, THEN THE Helm_Updater SHALL retry the push up to 3 times with a rebase before failing the job.
7. WHEN running on a pull request, THE Helm_Updater SHALL skip the commit and push step.

---

### Requirement 7: Workflow Observability

**User Story:** As a developer, I want clear workflow status and summary output, so that I can quickly understand what was built, pushed, and updated in each run.

#### Acceptance Criteria

1. WHEN the workflow completes, THE CI_CD_Workflow SHALL write a job summary to the GitHub Actions step summary listing each service processed, its Image_Tag, and the ECR_Repository URI.
2. WHEN a service is skipped due to no detected changes, THE CI_CD_Workflow SHALL include that service in the summary with a "skipped" status.
3. IF any job fails, THE CI_CD_Workflow SHALL surface the failure in the GitHub Actions UI with a non-zero exit code so that branch protection rules can block merges.

---

### Requirement 8: Workflow Security

**User Story:** As a platform engineer, I want the workflow to follow least-privilege and supply-chain security practices, so that the CI/CD pipeline does not become an attack vector.

#### Acceptance Criteria

1. THE CI_CD_Workflow SHALL pin all third-party GitHub Actions to a specific commit SHA rather than a mutable tag.
2. THE CI_CD_Workflow SHALL set `permissions` at the workflow level to the minimum required: `contents: write` (for committing Helm updates), `id-token: write` (for OIDC), and `pull-requests: read`.
3. THE CI_CD_Workflow SHALL not log or echo the values of any GitHub Actions secrets.
4. WHERE Docker image scanning is enabled, THE CI_CD_Workflow SHALL run a vulnerability scan on the built image before pushing to ECR and fail the job if critical vulnerabilities are found.
