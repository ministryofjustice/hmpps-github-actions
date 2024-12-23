#!/bin/bash
#
# To be run from the repo you wish to migrate:
# /bin/bash -c "$(curl -fsSL https://github.com/ministryofjustice/hmpps-github-actions/raw/refs/heads/main/migrate-repo.sh)"
#
# This will prevent three options:
# [1] Security workflows only - to delete all existing security workflows and replace with Github Actions OWASP / trivy and veracode workflows for
# the given project type.
# [2] Deployment only - to delete all existing deployment workflows and replace with the Github Actions deployment workflows for the given project type.
# [3] Complete migration - to delete all existing workflows and replace with the GHA 
#
#
# CONSIDERATIONS
 
# General
# --------
# Requires yq to be installed and gh to be installed (both can be done using brew install yq gh)
# Note that yq will reformat your circleci yaml file so worth checking the results before raising
# PRs especially if you've got multi-line commands in your file.

# Security
# --------
# The hmpps-sre-app bot needs to be added to private repositories and SECURITY_ALERTS_SLACK_CHANNEL_ID repository variable
# defined - see docs/security-migration.md for more information.
#
# Note: This script can be run multiple times to generate different cron expressions / refresh from the template.
#

# Deployments
# -----------
# The hmpps-sre-app bot needs to be added to private repositories and PROD_RELEASES_SLACK_CHANNEL (and optionally PREPROD_RELEASES_SLACK_CHANNEL) repository variable
# defined - see docs/deployment-migration.md for more information.


set -euo pipefail

if ! command -v yq &> /dev/null; then
  echo "Error: yq is not installed. Please install yq before running this script. This can be installed via brew: 'brew install yq'"
  exit 1
fi

if ! command -v gh &> /dev/null; then
  echo "Error: gh is not installed. Please install gh before running this script. This can be installed via brew: 'brew install gh'"
  exit 1
fi

CHANNEL_ID=$(yq  -r .parameters.alerts-slack-channel.default .circleci/config.yml)
REPO_NAME="${PWD##*/}"

if [[ $CHANNEL_ID != "null" ]]; then
  echo "updating CHANNEL_ID to '$CHANNEL_ID'"  

  gh variable set SECURITY_ALERTS_SLACK_CHANNEL_ID --body "${CHANNEL_ID}" -R "ministryofjustice/${REPO_NAME}"
else
  echo "CHANNEL_ID not available in circleci config. Check value at https://github.com/ministryofjustice/${REPO_NAME}/settings/variables/actions "
fi

echo "Using '$CHANNEL_ID' as the slack channel for security alerts"

migrate_kotlin_security_jobs() {
  yq -i 'del(.workflows.security) | del(.workflows.security-weekly) | del(.parameters.alerts-slack-channel)' .circleci/config.yml
  mkdir -p .github/workflows

  gh api repos/ministryofjustice/hmpps-github-actions/contents/templates/workflows/security_owasp.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_owasp.yml
  gh api repos/ministryofjustice/hmpps-github-actions/contents/templates/workflows/security_trivy.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_trivy.yml
  gh api repos/ministryofjustice/hmpps-github-actions/contents/templates/workflows/security_veracode_pipeline_scan.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_veracode_pipeline_scan.yml
  gh api repos/ministryofjustice/hmpps-github-actions/contents/templates/workflows/security_veracode_policy_scan.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_veracode_policy_scan.yml

  RANDOM_HOUR=$((RANDOM % (9 - 3 + 1) + 3))
  RANDOM_MINUTE=$((RANDOM%60))
  RANDOM_MINUTE2=$((RANDOM%60))

  for file in security_owasp.yml security_trivy.yml security_veracode_pipeline_scan.yml; do
    yq -i ".on.schedule[].cron=\"$RANDOM_MINUTE $RANDOM_HOUR * * MON-FRI\" | .on.schedule[].cron line_comment=\"Every weekday at $(printf "%02d:%02d" $RANDOM_HOUR $RANDOM_MINUTE) UTC\"" .github/workflows/$file
  done

  yq -i ".on.schedule[].cron=\"$RANDOM_MINUTE2 $RANDOM_HOUR * * 1\" | .on.schedule[].cron line_comment=\"Every Monday at $(printf "%02d:%02d" $RANDOM_HOUR $RANDOM_MINUTE2) UTC\"" .github/workflows/security_veracode_policy_scan.yml
}

migrate_node_security_jobs() {
  yq -i 'del(.workflows.security) | del(.workflows.security-weekly) | del(.parameters.alerts-slack-channel)' .circleci/config.yml
  mkdir -p .github/workflows

  gh api repos/ministryofjustice/hmpps-template-typescript/contents/templates/workflows/security_npm_dependency.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_npm_dependency.yml
  gh api repos/ministryofjustice/hmpps-template-typescript/contents/templates/workflows/security_trivy.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_trivy.yml
  gh api repos/ministryofjustice/hmpps-template-typescript/contents/templates/workflows/security_veracode_pipeline_scan.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_veracode_pipeline_scan.yml
  gh api repos/ministryofjustice/hmpps-template-typescript/contents/templates/workflows/security_veracode_policy_scan.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_veracode_policy_scan.yml

  RANDOM_HOUR=$((RANDOM % (9 - 3 + 1) + 3))
  RANDOM_MINUTE=$((RANDOM%60))
  RANDOM_MINUTE2=$((RANDOM%60))

  for file in security_npm_dependency.yml security_trivy.yml security_veracode_pipeline_scan.yml; do
    yq -i ".on.schedule[].cron=\"$RANDOM_MINUTE $RANDOM_HOUR * * MON-FRI\" | .on.schedule[].cron line_comment=\"Every weekday at $(printf "%02d:%02d" $RANDOM_HOUR $RANDOM_MINUTE) UTC\"" .github/workflows/$file
  done

  yq -i ".on.schedule[].cron=\"$RANDOM_MINUTE2 $RANDOM_HOUR * * 1\" | .on.schedule[].cron line_comment=\"Every Monday at $(printf "%02d:%02d" $RANDOM_HOUR $RANDOM_MINUTE2) UTC\"" .github/workflows/security_veracode_policy_scan.yml
}

migrate_kotlin_deployment_jobs() {
  yq -i 'del(.workflows.build-test-and-deploy)' .circleci/config.yml
  mkdir -p .github/workflows
  gh api repos/ministryofjustice/hmpps-template-kotlin/contents/templates/workflows/pipeline.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/deployments.yml
}

migrate_node_deployment_jobs() {
  yq -i 'del(.workflows.build-test-and-deploy)' .circleci/config.yml
  mkdir -p .github/workflows
  gh api repos/ministryofjustice/hmpps-template-typescript/contents/templates/workflows/pipeline.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/pipeline.yml
}


## main script starts here

echo "Migration script for CircleCI -> Github Actions"
echo "==============================================="
echo
echo "This script will migrate elements of CircleCI workflows to Github Actions."
echo "Please pick one of the following options by typing the corresponding number and hitting Enter:"
echo
echo "1. Migrate security workflows only"
echo "2. Migrate deployment workflows only"
echo "3. Migrate security and deployment workflows"
echo "Any other selection will exit"

read -p "Enter your selection: " selection 
if [[ $selection -eq 1 ]]; then
  echo "Migrating security workflows only"
elif [[ $selection -eq 2 ]]; then
  echo "Migrating deployment workflows only"
elif [[ $selection -eq 3 ]]; then
  echo "Migrating security and deployment workflows"
else
  echo "Exiting"
  exit 0
fi


if [[ -f "package.json" ]]; then
  if [[ $selection && 1 ]]; then
    echo "Migrating Node security jobs"
    migrate_node_security_jobs
  fi
elif [[ -f "build.gradle.kts" ]]; then
  if [[ $selection && 1 ]]; then
    echo "Migrating Kotlin security jobs"
    migrate_kotlin_security_jobs
  fi
else
    echo "No package.json or build.gradle.kts found."
    echo "No security jobs will be migrated"
fi

if [[ $selection && 2 ]] ; then
  echo "Migrating deployment jobs"

# check to see if we need to do anything particular with the deployment jobs depending on the project type
  if [[ -f "package.json" ]]; then
    migrate_node_deployment_jobs
    
  elif [[ -f "build.gradle.kts" ]]; then
    migrate_kotlin_deployment_jobs
    
  else
    echo "No package.json or build.gradle.kts found."
    echo "No deployment jobs will be migrated"
  fi

fi


echo "
  The 'HMPPS SRE App Slack bot' may need to be added to the '$CHANNEL_ID' slack channel:

  * In slack use the /invite command.
  * Select 'Add apps to this channel', and look for the 'hmpps-sre-app' app.
  * Click 'Add' - this will enable messages to be sent by the bot.
"
