# hmpps-github-actions

GitHub Actions for HMPPS projects.


## Overview

This repository contains a library of reusable GitHub workflows for use by other projects. These include:

- security scans
- testing / deployments
- slack messaging templates

### Build / deploy workflows

- `deploy_env`: orchestrates deployment to a Cloud Platforms environment
- `docker_build`: builds a Docker image (including options for multiplatform)
- `docker_build_ecr`: builds and tags a Docker image for ECR workflows
- `docker_push`: pushes a Docker image
- `docker_sbom`: generates software bill of materials data for container images
- `docker_sign`: signs Docker images
- `sentry_release_and_deploy`: creates and deploys Sentry releases

### Test workflows

#### Gradle
- `gradle_verify`: runs a Gradle check with optional Localstack & Postgres services
- `gradle_localstack_verify`: runs Gradle checks with Localstack
- `gradle_postgres_verify`: runs Gradle checks with Postgres
- `gradle_localstack_postgres_verify`: runs Gradle checks with Localstack and Postgres
- `kotlin_validate`: runs a Gradle check

#### Node
- `node_build`: runs a node build
- `node_integration_tests`: runs integration tests against a node installation with optional Redis service
- `node_unit_tests`: runs unit tests against a node installation with optional Redis service

#### Helm
- `test_helm_lint`: validates Helm configurations

#### Python
- `test_python_lint`: validates Python linting rules


### Security workflows

- NPM dependency
- NPM outdated
- OWASP reports
- Snyk scan (public, private, and ECR variants)
- Veracode pipeline scan
- Veracode policy scan
- CodeQL scan (repository code and GitHub Actions variants)

### Utility workflows

- `backup_repository`: creates a repository backup workflow run
- `cancel_outdated_waiting_workflows`: cancels superseded queued workflow runs

For the complete and up-to-date list of reusable workflows, see `.github/workflows/`.

### Shared Actions
To ensure actions are SHA-pinned, shared actions have been migrated to [hmpps-github-shared-actions](https://github.com/ministryofjustice/hmpps-github-shared-actions).

## Migrating from CircleCI

Documentation for migrating security scans from CircleCI to GitHub Actions can be found in [this document](docs/security-migration.md).
Documentation for migrating build/test/deploy workflows from CircleCI to GitHub Actions can be found in [this document](docs/workflow-migration.md).

## Templates

For calling examples, use template repositories and migration docs.

*Note:* Examples of security scans can be found within the [Kotlin](https://github.com/ministryofjustice/hmpps-template-kotlin/tree/main/.github/workflows) and [TypeScript](https://github.com/ministryofjustice/hmpps-template-typescript/tree/main/.github/workflows) repositories.


## Version Control

Workflows are referred to by the SHA of the current release, with a comment referring to the tag, for example:

```
    - uses: ministryofjustice/hmpps-github-shared-actions/.github/actions/security_owasp_reports@SHA #vx.y.z
```

When a new release is issued in `hmpps-github-shared-actions`, all of these referred workflows (as well as the calling ones within applications) will need to be updated as well for new SHA.

### Tagging workflow

Use the following process when creating or correcting release tags:

1. In GitHub UI, draft a new release first and decide the version bump type:

- **Major** (`vX.0.0`): breaking changes that require consumers to change configuration, workflow inputs, or behavior expectations.
- **Minor** (`vX.Y.0`): backward-compatible new workflows, new optional inputs, or additive features.
- **Patch** (`vX.Y.Z`): backward-compatible fixes, documentation updates, dependency/action bumps, or internal refactoring with no consumer-facing break.

After creating the draft release, copy the release commit SHA and use that SHA in the next steps.

2. Sync local tag state with remote tags.

```sh
git fetch --tags
```

3. Confirm the commit you want tags to point to (use the SHA from the release you just drafted).

```sh
git show --no-patch --oneline 57c5abe47a8ebc9b1caa28ac601472a77036ab4d
```

4. Check current tag targets.

```sh
git rev-list -n 1 v2.16
git rev-list -n 1 v2.16.0
```

5. Move tags to the target commit.

```sh
COMMIT=57c5abe47a8ebc9b1caa28ac601472a77036ab4d
git tag -f v2.16 "$COMMIT"
git tag -f v2.16.0 "$COMMIT"
```

6. Push updated tags to remote.

```sh
git push origin +refs/tags/v2.16 +refs/tags/v2.16.0
```

7. Verify remote tag targets after push.

```sh
git ls-remote --tags --refs origin | grep -E 'refs/tags/v2\.16(\.0)?$'
```

### Releasing

To perform a release:

* Update the WORKFLOW_VERSION across the project (if doing a major release)
* Ensure the `CHANGELOG.md` has been updated
* Create a pull request and get it merged
* Create a new release and increment the version tag appropriately.
* Update the short version tags for `vx`, `vx.y`.

For a new version, for example `v2.1.5`:
```sh
export RELEASE_SHA=57c5abe47a8ebc9b1caa28ac601472a77036ab4d
git tag -f v2 "$RELEASE_SHA" && git push -f origin v2
git tag -f v2.1 "$RELEASE_SHA" && git push -f origin v2.1
git tag -f v2.1.5 "$RELEASE_SHA" && git push -f origin v2.1.5
```

Use the steps in **Tagging workflow** above when correcting existing tags or moving tags to a specific commit.

This requires maintenance permissions (or greater) on this repository.

## Testing Renovate Upgrade PRs for hmpps-github-actions

When Renovate creates a PR to upgrade dependencies or actions in hmpps-github-actions, you need to verify the changes before merging. Since hmpps-github-actions is a central library, its workflows are consumed by other repositories.

Follow these steps to test the changes:

##### 1. Identify the Changed Workflow

Review the Renovate PR in hmpps-github-actions (example: https://github.com/ministryofjustice/hmpps-github-actions/pull/159).
Check which workflow/action file was modified (e.g.: .github/workflows/security_codeql.yml, .github/actions/snyk-scan/action.yml etc.).


##### 2. Find a Repository that uses this workflow

Search for a repository that references the changed workflow from hmpps-github-actions.
Look in .github/workflows/*.yml files for lines like:
```
ministryofjustice/hmpps-github-actions/.github/workflows/<workflow>.yml@SHA # <version>
```
It may be that the update is within an action file rather than a parent workflow. To validate this, the parent workflow within hmpps-github-actions will also need to be modified to point to the patched action, for example in `workflows/deploy_env.yaml`, and then a repository that uses the workflow can be modified appropriately.

For example (in a shared GitHub workflow):
uses: ministryofjustice/hmpps-github-shared-actions/.github/actions/slack_release_results@<branch_name>

Obviously, don't forget to put this back to the appropriate tag when the PR is raised.

##### 3. Create a Test Branch in Target Repository

In the identified repository:

Create a new branch (e.g., test-renovate-upgrade).
Update the workflow reference to point to the branch from the Renovate PR instead of the current version:
```
ministryofjustice/hmpps-github-actions/.github/workflows/<workflow>.yml@<renovate-branch-name>
```
Example:
```
ministryofjustice/hmpps-github-actions/.github/workflows/codeql.yml@renovate/github-codeql-action-3.x
```

##### 4. Ensure the New Version is Used in Setup Job

In the workflow steps, confirm that the setup job or action version matches the updated version from the Renovate PR.
For example, if Renovate upgraded github/codeql-action to v4, verify that the workflow uses v4.

##### 5. Trigger the Workflow

Push the branch and trigger the workflow (manually or via a commit).
Monitor the run in Actions tab to ensure:

The workflow executes successfully.
The updated action works as expected.

##### 6. Report Back

`If the test passes:` Approve and merge the Renovate PR in hmpps-github-actions.

**Note:** Once the PR has been merged, it is recommended to combine a number of updates together under a new patch tag, rather than tagging each individually. 

`If it fails:` Investigate and fix issues before merging.

### Workflow version discovery

Workflow version usage is already discovered centrally.

- `hmpps-github-discovery` runs on a schedule and scans repository workflows.
- Results are saved into the `components.versions` field.
- This data is shown in the Developer Portal [Component dependencies](https://developer-portal.hmpps.service.justice.gov.uk/dependencies) view.
- Renovate and Dependabot then check versions in repositories and raise upgrade PRs.

### How workflow versions are upgraded in repositories

Repositories that consume these shared workflows are upgraded through automated dependency tooling.

1. A new workflow release/tag is created in this repository.
2. Consumer repositories reference these workflows in their `.github/workflows/*.yml` files, they either specify major or minor tags.
3. Renovate and Dependabot detect newer versions from `ministryofjustice/hmpps-github-actions`.
4. They raise pull requests in consumer repositories to update workflow references.
5. Teams review and merge those PRs to adopt the newer workflow version.

This keeps workflow upgrades visible, reviewable, and consistent across repositories.

