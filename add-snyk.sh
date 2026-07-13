#!/bin/bash
#
migration_script_info='

Add Snyk workflow script - version 0.1
=====================================================
'

# Functions

#############################
# MIGRATION - SECURITY JOBS #
#############################

migrate_kotlin_security_jobs() {
  mkdir -p .github/workflows

  rm .github/workflows/security_trivy*.yml || true
  gh api repos/ministryofjustice/hmpps-template-kotlin/contents/.github/workflows/security_owasp.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_owasp.yml
  gh api repos/ministryofjustice/hmpps-template-kotlin/contents/.github/workflows/security_snyk_scan.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_snyk_scan.yml
  gh api repos/ministryofjustice/hmpps-template-kotlin/contents/.github/workflows/security_veracode_pipeline_scan.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_veracode_pipeline_scan.yml
  gh api repos/ministryofjustice/hmpps-template-kotlin/contents/.github/workflows/security_veracode_policy_scan.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_veracode_policy_scan.yml

  RANDOM_HOUR=$((RANDOM % (9 - 3 + 1) + 3))
  RANDOM_MINUTE=$((RANDOM%60))
  RANDOM_MINUTE2=$((RANDOM%60))

  for file in security_owasp.yml security_snyk_scan.yml security_veracode_pipeline_scan.yml; do
    yq -i ".on.schedule[].cron=\"$RANDOM_MINUTE $RANDOM_HOUR * * MON-FRI\" | .on.schedule[].cron line_comment=\"Every weekday at $(printf "%02d:%02d" $RANDOM_HOUR $RANDOM_MINUTE) UTC\"" .github/workflows/$file
  done

  yq -i ".on.schedule[].cron=\"$RANDOM_MINUTE2 $RANDOM_HOUR * * 1\" | .on.schedule[].cron line_comment=\"Every Monday at $(printf "%02d:%02d" $RANDOM_HOUR $RANDOM_MINUTE2) UTC\"" .github/workflows/security_veracode_policy_scan.yml
}

migrate_node_security_jobs() {
  mkdir -p .github/workflows

  rm .github/workflows/security_trivy*.yml || true
  gh api repos/ministryofjustice/hmpps-template-typescript/contents/.github/workflows/security_npm_dependency.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_npm_dependency.yml
  gh api repos/ministryofjustice/hmpps-template-typescript/contents/.github/workflows/security_snyk_scan.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_snyk_scan.yml
  gh api repos/ministryofjustice/hmpps-template-typescript/contents/.github/workflows/security_veracode_pipeline_scan.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_veracode_pipeline_scan.yml
  gh api repos/ministryofjustice/hmpps-template-typescript/contents/.github/workflows/security_veracode_policy_scan.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_veracode_policy_scan.yml

  RANDOM_HOUR=$((RANDOM % (9 - 3 + 1) + 3))
  RANDOM_MINUTE=$((RANDOM%60))
  RANDOM_MINUTE2=$((RANDOM%60))

  for file in security_npm_dependency.yml security_snyk_scan.yml security_veracode_pipeline_scan.yml; do
    yq -i ".on.schedule[].cron=\"$RANDOM_MINUTE $RANDOM_HOUR * * MON-FRI\" | .on.schedule[].cron line_comment=\"Every weekday at $(printf "%02d:%02d" $RANDOM_HOUR $RANDOM_MINUTE) UTC\"" .github/workflows/$file
  done

  yq -i ".on.schedule[].cron=\"$RANDOM_MINUTE2 $RANDOM_HOUR * * 1\" | .on.schedule[].cron line_comment=\"Every Monday at $(printf "%02d:%02d" $RANDOM_HOUR $RANDOM_MINUTE2) UTC\"" .github/workflows/security_veracode_policy_scan.yml
}

###########################
# MAIN SCRIPT STARTS HERE #
###########################


# Initialisation
set -euo pipefail

if ! command -v yq &> /dev/null; then
  echo "Error: yq is not installed. Please install yq before running this script. This can be installed via brew: 'brew install yq'"
  exit 1
fi

if ! command -v gh &> /dev/null; then
  echo "Error: gh is not installed. Please install gh before running this script. This can be installed via brew: 'brew install gh'"
  exit 1
fi


## Main menu
echo
echo "Adding snyk action"
echo "==============================================="
echo

# backup CircleCI config

if [[ -f "package.json" ]]; then
    echo "Migrating Node security jobs"
    migrate_node_security_jobs
elif [[ -f "build.gradle.kts" ]]; then
    echo "Migrating Kotlin security jobs"
    migrate_kotlin_security_jobs
else
    echo "No package.json or build.gradle.kts found."
    echo "No security jobs will be migrated"
fi

echo "FIN!"
