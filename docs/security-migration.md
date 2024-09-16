# Migrating security scans from CircleCI to Github Actions

## Introduction

Periodic (so non-pipeline) security scans have, for a long while, been run by CircleCI. Towards the bottom of the `.circleci/config.yml` file in a number of projects, there is a collection of jobs that are instigated on a schedule.

It's now possible to run scans and upload them (when appropriate) to the Code Scanning section of the repo and send a Slack notification using Github actions.

This document details how to move over from CircleCI for each scan and what files and configurations are required.

Template workflows can be found in the `templates` directory of this repository.


## Components

### Common components

Currently the only common component that's required for all action is the **Security Alerts Slack Channel ID**. 

This needs to be added as the repository variables with the name: **`SECURITY_ALERTS_SLACK_CHANNEL_ID`**

If this channel is empty, no slack messages will be sent within any of these workflows below.


### security_trivy

#### What to comment out:

within `.circleci/config.yml` of the target project, comment out or remove the following:

```
      - hmpps/trivy_latest_scan:
          slack_channel: << pipeline.parameters.alerts-slack-channel >>
          context:
            - hmpps-common-vars
```

#### What to add

From this repo, copy:
- from `/templates/security_trivy.yml` 
- to `./github/workflows/security_trivy.yml` of the target project.

#### Outputs

If the workflow runs successfully, and the scan identifies issues:

- Trivy automatically creates a Sarif file which gets uploaded to Github, and generates an open alert for each item, within Code Scanning

- It will also send a Slack message to notify that the workflow has identified issues, and links to Code Scanning for that repository.

If the workfow fails, Github sends a slack message and an email to notify users.


### security_owasp

#### What to comment out:

within `.circleci/config.yml` of the target project, comment out or remove the following:

```
      - hmpps/gradle_owasp_dependency_check:
          cache_key: "v2_0"
          jdk_tag: "21.0"
          slack_channel: << pipeline.parameters.alerts-slack-channel >>
          context:
            - hmpps-common-vars
```

#### What to add

From this repo, copy:
- from `/templates/security_owasp.yml` 
- to`./github/workflows/security_owasp.yml` of the target project.

#### Outputs

If the workflow runs successfully, and the scan identifies issues:

- OWASP automatically creates a Sarif file which gets uploaded to Github, and generates an open alert for each item, within Code Scanning

- It will also send a Slack message to notify that the workflow has identified issues, and links to Code Scanning for that repository.

If the workfow fails, Github sends a slack message and an email to notify users.


### security_npm_dependency

#### What to comment out:

within `.circleci/config.yml` of the target project, comment out or remove the following:

```
     - hmpps/npm_security_audit:
         slack_channel: << pipeline.parameters.alerts-slack-channel >>
         node_tag: << pipeline.parameters.node-version >>
         context:
           - hmpps-common-vars
```

#### What to add

Within templates copy `security_npm_dependency.yml` into `./github/workflows` of the target project.

Furthermore, to translate the npm audit report into SARIF format, a python script needs to be copied:
- from `scripts/auditjson_to_sarif.py`
- to `./github/scripts` on the target project.


#### Outputs

If the workflow runs successfully, and the scan identifies issues:

- The workflow runs a script to translate the json response into SARIF format and uploads it to Code Scanning

- It will also send a Slack message to notify that the workflow has identified issues, and links to Code Scanning for that repository.

- The Slack message will also display a table of the vunerable components.

If the workfow fails, Github sends a slack message and an email to notify users.



### security_npm_outdated

*(note: generally only used on the templates project)*

#### What to comment out:

within `.circleci/config.yml` of the target project, comment out or remove the following:

```
     - hmpps/npm_outdated:
         slack_channel: << pipeline.parameters.alerts-slack-channel >>
         node_tag: << pipeline.parameters.node-version >>
         context:
           - hmpps-common-vars
```

#### What to add

Within templates copy `security_npm_outdated.yml` into `./github/workflows` of the target project.

Furthermore, to translate the npm audit report into SARIF format, a python script needs to be copied:
- from `scripts/outdated_to_slack.py`
- to `./github/scripts` on the target project.


#### Outputs

If the workflow runs successfully, and the scan identifies issues:

- A text file is uploaded which gets uploaded to Github as an Action artifact

- It will also send a Slack message to notify that the workflow has identified issues, along with a table of the outdated components.

If the workfow fails, Github sends a slack message and an email to notify users.


### security_veracode_pipeline_scan

#### What to comment out:

within `.circleci/config.yml` of the target project, comment out or remove the following:

```
  - hmpps/veracode_pipeline_scan:
      slack_channel: << pipeline.parameters.alerts-slack-channel >>
        context:
          - veracode-credentials
          - hmpps-common-vars
```

#### What to add

Within templates copy `security_veracode_pipeline_scan.yml` into `./github/workflows` of the target project.

To ensure all the scans don't run at the same time, please change the time of this scan.

#### Outputs

Veracode processes the reports, which are ultimately made available in the [Developer Portal](https://developer-portal.hmpps.service.justice.gov.uk/reports/veracode).

If the workfow fails, Github sends a slack message and an email to notify users.


### security_veracode_policy_scan

#### What to comment out:

within `.circleci/config.yml` of the target project, comment out or remove the following:

```
security-weekly:
    triggers:
      - schedule:
          cron: "50 3 * * 1"
          filters:
            branches:
              only:
                - main
    jobs:
      - hmpps/veracode_policy_scan:
          slack_channel: << pipeline.parameters.alerts-slack-channel >>
          context:
            - veracode-credentials
            - hmpps-common-vars

```

#### What to add

Within templates copy `security_veracode_policy_scan.yml` into `./github/workflows` of the target project.

To ensure all the scans don't run at the same time, please change the time of this scan.

#### Outputs

Veracode processes the reports, which are ultimately made available in the [Developer Portal](https://developer-portal.hmpps.service.justice.gov.uk/reports/veracode).

If the workfow fails, Github sends a slack message and an email to notify users.


### TODO:

- Update the bootstrap to change the random time value from making changes within config.yml to the specific github actions
- Update the bootstrap to add SECURITY_ALERTS_SLACK_CHANNEL_ID to the repo based on Service Catalogue configuration
- Optionally create a Github issue (and notify) when a code scan identifies a vulnerability - as per [this project](https://github.com/ministryofjustice/hmpps-probation-integration-services/blob/main/.github/workflows/security.yml) 

