# Migrating build/test/deployment from CircleCI to Github Actions

## Introduction
This document covers the basics of migrating the main build/test/deploy pipeline from from CircleCI to Github Actions, and the script that supports the migration.

Because CircleCI has been around for many years, and each project may well have its own specific flows for building, testing and deployment, only the most elementary sections of the pipeline will be populated. It is left up to the development team to add features such as Snyk scanning and custom Slack messages, based on the remaining CircleCI configuration and the backed-up version.

This is intended to be a 'get you started' process, although it may well be that other common components are added to the migration if there are common elements.

### Other documentation

More information on the process of migrating to Github Actions (including required Cloud Platform configurations) can be found in the [HMPPS Shared Tooling Tech Docs](https://tech-docs.hmpps.service.justice.gov.uk/shared-tooling/migrating-to-GHA/)

## Components
The migration script solely to translate the **build-test-and-deploy** jobs under **workflows:** in `.circleci/config.yml`:
```
workflows:
  build-test-and-deploy:
.
.
    jobs:
```

to the templated jobs within `.github/workflows/pipeline.yml`:
```
jobs:
```

There will be sufficient parameters to carry out a simple deployment.

### Docker Build
This will either call `build_multiplatform_docker` or `build_docker` with custom parameters.

#### Parameters

- branch filters
- additional_docker_build_args
- docker_multiplatform

Note: Github Actions doesn't suppport regex filtering of branch filters, so it uses either 'startsWith' or 'contains'


### Deploy
This will create a deployment activity for each corresponding environment within `config.yml`

Approval gates (a.k.a. **manual approval**, or **approvals** in CircleCI) are set within the repository itself, so aren't included within the deployment here.  These values are set by the Cloud Platform configuration, but can be verified in the Web UI at **environments > (env name) > Required reviewers** and ensuring this checkbox is checked.  See GitHub's ["Deployments and environments"](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments#required-reviewers) documentation for further information.

The *needs* configurations are based on any 'required' element associated with the request-${each_env}-approval.requires[] configuration

#### Parameters

- branch filters
- needs (previous deployment)
- helm_timeout
- helm_dir
- helm_additional_args

### Executors

There are a number of CircleCI projects that refer to executors to run more than one service (eg. Node + Redis, or Java + Postgres)
Github Actions does not have an equivalent, so separate workflows are required to carry out the job, which load the additional
services (eg. Redis / Postgres). The migration script will identify the most common executors and insert templates to use these services into a
local workflow. The developer can then migrate the specifics of the tests (from the original config.yml) to this workflow and create a reference
from the pipeline. This will be logged as part of the migration script and the developer will be notified as to which jobs will need to be checked.

The migration script contains checks for these CircleCI executors, the behaviours of which are commented within the script:

- node_redis
- java_postgres
- java_localstack_postgres (including db_name)
- localstack


### Removal
Once the tasks have been migrated, the `build-test-and-deploy` workflow is removed from `.circleci/config.yml` to prevent concurrent deployment in CircleCI

The previous configuration will be retained in a backup file (config.bak.yyyymmdd_HHMMSS)


## Automation

The `migrate-repo.sh` script can be run from a checked out repo:
```bash
/bin/bash -c "$(curl -fsSL https://github.com/ministryofjustice/hmpps-github-actions/raw/refs/heads/main/migrate-repo.sh)"
```

### TODO:
Depending on feedback from developers, further parameters or build/test/deploy steps may be migrated
