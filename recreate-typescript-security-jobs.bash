#!/bin/bash
#
# To be run from inside the github project that you would like to create / update the security jobs; expected usage is:
# ../hmpps-github-actions/recreate-typescript-security-jobs.bash
#
# Will delete all existing security workflows and replace with the standard npm / trivy and veracode workflows for
# typescript projects.
#
# Requires yq to be installed and hmpps-github-actions to be checked out (and up to date) at the same level as this
# github project. Also the hmpps-sre-app needs to be added and SECURITY_ALERTS_SLACK_CHANNEL_ID repository variable
# defined - see docs/security-migration.md for more information.
#
# Can be run multiple times to generate different cron expressions / refresh from the template.
#
# Note that yq will reformat your circleci yaml file so worth checking the results before raising
# PRs especially if you've got multi-line commands in your file.

function get_yaml() {
  yml_file=$1
  gh api repos/ministryofjustice/hmpps-template-typescript/contents/.github/workflows/$yml_file -H "Accept: application/vnd.github.v3.raw" > .github/workflows/$yml_file
}

if [[ -w .circleci/config.yml ]]; then
  yq -i 'del(.workflows.security) | del(.workflows.security-weekly)' .circleci/config.yml
fi

mkdir -p .github/workflows

# Tidy up after previous run created auditjson_to_sarif.py
if [[ -w .github/scripts/auditjson_to_sarif.py ]]; then
  rm .github/scripts/auditjson_to_sarif.py
  rmdir .github/scripts >/dev/null
fi

RANDOM_HOUR=$((RANDOM % (9 - 3 + 1) + 3))
RANDOM_MINUTE=$((RANDOM%60))
RANDOM_MINUTE2=$((RANDOM%60))

# daily checks
for file in security_npm_dependency.yml security_trivy.yml security_veracode_pipeline_scan.yml security_codeql_actions_scan.yml; do
  get_yaml $file
  yq -i ".on.schedule[].cron=\"$RANDOM_MINUTE $RANDOM_HOUR * * MON-FRI\" | .on.schedule[].cron line_comment=\"Every weekday at $(printf "%02d:%02d" $RANDOM_HOUR $RANDOM_MINUTE) UTC\"" .github/workflows/$file
done

# weekly checks
file=security_veracode_policy_scan.yml
get_yaml $file
yq -i ".on.schedule[].cron=\"$RANDOM_MINUTE2 $RANDOM_HOUR * * 1\" | .on.schedule[].cron line_comment=\"Every Monday at $(printf "%02d:%02d" $RANDOM_HOUR $RANDOM_MINUTE2) UTC\"" .github/workflows/$file
