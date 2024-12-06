#!/bin/bash
#
# To be run from the repo you wish to migrate:
# /bin/bash -c "$(curl -fsSL https://github.com/ministryofjustice/hmpps-github-actions/raw/refs/heads/main/migrate-repo.sh)"
#
# Will delete all existing security workflows and replace with the standard owasp / trivy and veracode workflows for
# the given project type.
#
# Requires yq to be installed and gh to be installed  Also the hmpps-sre-app needs to be added and SECURITY_ALERTS_SLACK_CHANNEL_ID repository variable
# defined - see docs/security-migration.md for more information.
#
# Can be run multiple times to generate different cron expressions / refresh from the template.
#
# Note that yq will reformat your circleci yaml file so worth checking the results before raising
# PRs especially if you've got multi-line commands in your file.

set -euo pipefail

if ! command -v yq &> /dev/null; then
  echo "Error: yq is not installed. Please install yq before running this script."
  exit 1
fi

if ! command -v gh &> /dev/null; then
  echo "Error: gh is not installed. Please install gh before running this script."
  exit 1
fi

read -p "Please enter the slack channel name (without the '#' character): " CHANNEL_ID

if [[ ${CHANNEL_ID:0:1} == "#" ]]; then
  echo "Error: CHANNEL_ID is not set or starts with a hash character. Please set the CHANNEL_ID env variable before running this script."
  exit 1
fi

REPO_NAME="${PWD##*/}"

gh variable set SECURITY_ALERTS_SLACK_CHANNEL_ID --body "${CHANNEL_ID}" -R "ministryofjustice/${REPO_NAME}"

migrate_kotlin_security_jobs() {
  yq -i 'del(.workflows.security) | del(.workflows.security-weekly)' .circleci/config.yml
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
  yq -i 'del(.workflows.security) | del(.workflows.security-weekly)' .circleci/config.yml
  mkdir -p .github/workflows

  gh api repos/ministryofjustice/hmpps-github-actions/contents/templates/workflows/security_npm_dependency.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_npm_dependency.yml
  gh api repos/ministryofjustice/hmpps-github-actions/contents/templates/workflows/security_trivy.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_trivy.yml
  gh api repos/ministryofjustice/hmpps-github-actions/contents/templates/workflows/security_veracode_pipeline_scan.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_veracode_pipeline_scan.yml
  gh api repos/ministryofjustice/hmpps-github-actions/contents/templates/workflows/security_veracode_policy_scan.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_veracode_policy_scan.yml

  RANDOM_HOUR=$((RANDOM % (9 - 3 + 1) + 3))
  RANDOM_MINUTE=$((RANDOM%60))
  RANDOM_MINUTE2=$((RANDOM%60))

  for file in security_npm_dependency.yml security_trivy.yml security_veracode_pipeline_scan.yml; do
    yq -i ".on.schedule[].cron=\"$RANDOM_MINUTE $RANDOM_HOUR * * MON-FRI\" | .on.schedule[].cron line_comment=\"Every weekday at $(printf "%02d:%02d" $RANDOM_HOUR $RANDOM_MINUTE) UTC\"" .github/workflows/$file
  done

  yq -i ".on.schedule[].cron=\"$RANDOM_MINUTE2 $RANDOM_HOUR * * 1\" | .on.schedule[].cron line_comment=\"Every Monday at $(printf "%02d:%02d" $RANDOM_HOUR $RANDOM_MINUTE2) UTC\"" .github/workflows/security_veracode_policy_scan.yml
}


if [[ -f "package.json" ]]; then
  migrate_node_security_jobs
elif [[ -f "build.gradle.kts" ]]; then
  migrate_kotlin_security_jobs
else
  echo "Error: Unable to determine project type. Please make sure you are running this script from a Node or Kotlin project."
  exit 1
fi

echo "
  The 'HMPPS SRE App Slack bot' may need to be added to the '$CHANNEL_ID' slack channel:

  * In slack use the /invite command.
  * Select 'Add apps to this channel', and look for the 'hmpps-sre-app' app.
  * Click 'Add' - this will enable messages to be sent by the bot.
"
