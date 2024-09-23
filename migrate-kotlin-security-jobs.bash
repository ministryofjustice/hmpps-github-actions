#!/bin/bash
#
# To be run from inside the github project that you would like to migrate, expected usage is:
# ../hmpps-github-actions/migrate-kotlin-security-jobs.bash
#
# Will delete all existing security workflows and replace with the standard owasp / trivy and veracode workflows for
# kotlin projects.
#
# Requires yq to be installed and hmpps-github-actions to be checked out (and up to date) at the same level as this
# github project. Also the hmpps-sre-app needs to be added and SECURITY_ALERTS_SLACK_CHANNEL_ID repository variable
# defined - see docs/security-migration.md for more information.
#
# Can be run multiple times to generate different cron expressions / refresh from the template.
#
# Note that yq will reformat your circleci yaml file so worth checking the results before raising
# PRs especially if you've got multi-line commands in your file.

yq -i 'del(.workflows.security) | del(.workflows.security-weekly)' .circleci/config.yml
mkdir -p .github/workflows

cp -a ../hmpps-github-actions/templates/security_owasp.yml .github/workflows
cp -a ../hmpps-github-actions/templates/security_trivy.yml .github/workflows
cp -a ../hmpps-github-actions/templates/security_vera*.yml .github/workflows

RANDOM_HOUR=$((RANDOM % (9 - 3 + 1) + 3))
RANDOM_MINUTE=$((RANDOM%60))
RANDOM_MINUTE2=$((RANDOM%60))

for file in security_owasp.yml security_trivy.yml security_veracode_pipeline_scan.yml; do
  yq -i ".on.schedule[].cron=\"$RANDOM_MINUTE $RANDOM_HOUR * * MON-FRI\" | .on.schedule[].cron line_comment=\"Every weekday at $(printf "%02d:%02d" $RANDOM_HOUR $RANDOM_MINUTE) UTC\"" .github/workflows/$file
done

yq -i ".on.schedule[].cron=\"$RANDOM_MINUTE2 $RANDOM_HOUR * * 1\" | .on.schedule[].cron line_comment=\"Every Monday at $(printf "%02d:%02d" $RANDOM_HOUR $RANDOM_MINUTE2) UTC\"" .github/workflows/security_veracode_policy_scan.yml
