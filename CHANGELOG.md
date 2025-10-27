## 0.1

First release

## 0.2

Finessing of workflows - better Sarif file for typescript reports

If no Slack channel is included, no messages will be sent.

## v0.3

Semantic versioning

This also uses inherited secrets in the template workflows to avoid having to add the local secrets to each one.

## v0.7

Inline python scripts to avoid having to run them locally (benefit: keeps any fixes/improvements inside the shared actions)

## v0.7.1

Change to `.github/workflows/security_veracode_policy_scan.yml`. Updated scan identifier string so it now includes the github action ID, github branch, github commit sha. This makes it easier to link the veracode scan results with a commit in the dev portal.

## v1

Initial release

## v2.0.0

Node version for node related tasks now derive versions based on a [version file](https://github.com/actions/setup-node/blob/main/docs/advanced-usage.md#node-version-file).
This defaults to `.nvmrc`.

There is a non-backwards compatible change included in this release which is the removal of the ability to specify a given node version using the `node_version` option. 

## v2.7.0

Add support for AWS ECR hosted container images in the `.github/workflow/docker_build.yml` workflow. 
