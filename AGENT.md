# Refactoring docker_build.yml and docker_build_ecr.yml maintaining backwards compatibility

## Context
We're migrating from using GHCR.io as our container repositories to ECR. This is because there is an edict to make repositories internal, and we have an insurmountable challenge to get Kubernetes to authenticate with anything but a PAT to pull from an internal container repository.

The key thing here is to make the existing workflows still work, while implementing the new functionality.

## Frustrations
1. The key frustration is `id-token: write` - this is required to push to ECR. Many of our calling pipelines (in well over 300 repositories) either [a] don't have permissions set, or [b] have permissions that don't include `id-token: write`, which - even if the shared workflow doesn't contain it, if a workflow it *conditionally* calls (eg. `docker_push_ecr.yml`) has an `id-token: write` requirement, it will fail due to lack of permissions. Consequently the multifunction `docker_build.yml` I have built that is intended to offer common elements to build and then spur off to push depending on the output registry won't work. 

2. Two repositories are using ECR already, and have implemented `docker_build_ecr.yml` - this has much of the functionality of what we need, but is missing a lot of the logic that has been built into `docker_build.yml`, including creating the app_version, signing and pushing to SBOM if requred. This is annoying, because ideally I would like to split out the mulitipurpose workflow above to one called `docker_build_ecr.yml`, but this already exists


## Requirements
I want to return docker_build.yml back to docker_build_orig.yml, so nothing changes in the workflows that use it.

Therefore I want to update `docker_build_ecr.yml` with all of the ECR functions of `docker_build.yml` without compromising the existing functionality, causing the repositories that currently use it to fail to deploy.