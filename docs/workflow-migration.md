# Migrating build/test/deployment from CircleCI to Github Actions

## Introduction
This document covers the basics of migrating the main build/test/deploy pipeline from from CircleCI to Github Actions, and the script that supports the migration.

Because CircleCI has been around for many years, and each project may well have its own specific flows for building, testing and deployment, only the most elementary sections of the pipeline will be populated. It is left up to the development team to add features such as Snyk scanning and custom Slack messages, based on the remaining CircleCI configuration and the backed-up version.

This is intended to be a 'get you started' process, although it may well be that other common components are added to the migration if there are common elements.

## Components
The migration script solely to translate the key jobs under **workflows:** in `.circleci/config.yml`:
```
workflows:
  build-test-and-deploy:
.
.
    jobs:
```

under the templated jobs within `.github/workflows/pipeline.yml`:
```
jobs:
```

### Docker Build
This will either call `build_multiplatform_docker` or `build_docker` with a number of parameters.

#### Parameters



## Automation

The `migrate-repo.sh` script can be run from a checked out repo:
```bash
/bin/bash -c "$(curl -fsSL https://github.com/ministryofjustice/hmpps-github-actions/raw/refs/heads/main/migrate-repo.sh)
```


### TODO:
