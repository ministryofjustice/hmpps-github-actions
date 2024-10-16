# hmpps-github-actions

Github actions for HMPPS projects


## Outline

This contains a library of Github actions for use by other projects. These include:

- security scans
- testing / deployments
- slack messaging templates

### Security workflows

- NPM dependency
- NPM outdated
- OWASP reports
- Trivy reports
- Veracode pipeline scan
- Veracode policy scan

#### Migrating from CircleCI

Documentation for migrating security scans from CircleCI to Github Actions can be found in [this document](docs/security-migration.md)


### Slack actions
- `slack_prepare_results`: filter non-Slack compatible text out of a text file and load it into a variable
- `slack_failure_results`: report on a failed operation with results as generated by slack_prepare_results
- `slack_codescan_notification`: links to the Codescan section of a repository to show the currently identified issues


## Templates

These workflows are called by other repositories. Templates to call these are in the `templates` directory.


## Version Control

Workflows and actions are referred to by the tags associated with the current release, eg:

```
    - uses: ministryofjustice/hmpps-github-actions/.github/actions/security_owasp_reports@v1 # WORKFLOW_VERSION
```

When a new release is issued, all of these referred workflows (as well as the calling ones within applications) will need to be updated as well.

### TODO

- Update the discovery tool to scan the version of Github Actions Workflows
