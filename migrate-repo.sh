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

  mkdir -p .github/workflows
  pipeline_file=".github/workflows/pipeline.yml"
  # Pull down the template pipeline and remove deploy_dev
  gh api repos/ministryofjustice/hmpps-template-kotlin/contents/.github/workflows/pipeline.yml -H "Accept: application/vnd.github.v3.raw"  | grep -v  "^ *#" | yq eval 'del(.jobs.deploy_dev)' > ${pipeline_file}

# load the list of build / test / deploy jobs into a string
# only build-test-deploy will be populated - the others will be added at the bottom and commented out
  all_btd_jobs=$(yq eval '.workflows | keys | map(select(test("build|test|deploy")))' .circleci/config.yml | awk '{print $2}')

# Create a list of environments that are deployed to
  workflow_jobs=$(yq eval '.workflows.build-test-and-deploy.jobs.[]' .circleci/config.yml)
  deploy_envs=$(yq eval '.workflows.build-test-and-deploy | select(.jobs[]."hmpps/deploy_env") | .jobs[] | select(has("hmpps/deploy_env")) | ."hmpps/deploy_env".env' .circleci/config.yml)

for each_env in $deploy_envs; do
  echo "Migrating deployment job for $each_env"
  env_params=$(yq eval '.workflows.build-test-and-deploy | select(.jobs[]."hmpps/deploy_env") | .jobs[] | select(has("hmpps/deploy_env")) | select(."hmpps/deploy_env".env == "'$each_env'")' .circleci/config.yml) 

# add the parameters one at a time
  echo "deploy_${each_env}:" >> ${pipeline_file}
  echo "  name: Deploy to the ${each_env} environment" >> ${pipeline_file}

# branches filter
  branch_filter=$(echo $env_params | yq .'hmpps/deploy_env.filters.branches.only[]')
  if [ -n "${branch_filter}" ]; then
    echo -n "  if: github.ref in [" >> ${pipeline_file}
    nb=0
    for each_branch in $(echo $branch_filter); do
      if [ $nb -eq 0 ] ; then
        then nb=1 
        else echo -n ',' 
      fi
      echo -n "'refs/heads/${each_branch}'"
    done >> ${pipeline_file}
    echo "]" >> ${pipeline_file}
  fi

  echo "  needs:" >> ${pipeline_file}
  echo "  - build" >> ${pipeline_file}
  echo "  - helm_lint" >> ${pipeline_file}

  # create the needs for non-dev environments
  if [ {each_env} != "dev" ]; then
    needs=$(echo "${workflow_jobs}" | yq eval '.workflows.build-test-and-deploy.jobs.[]' .circleci/config.yml | yq ".request-${each_env}-approval.requires[] | select(test(\"^deploy_\"))") 
    if [ -n "${needs}" ]; then
      echo "  - ${needs}" >> ${pipeline_file}
    fi
  fi
    echo "  uses: ministryofjustice/hmpps-github-actions/.github/workflows/deploy_env.yml@v2 # WORKFLOW_VERSION" >> ${pipeline_file}
    echo "  secrets: inherit" >> ${pipeline_file}

    echo "  with:" >> ${pipeline_file}
    echo "    environment: '${each_env}'" >> ${pipeline_file}
    echo "    app_version: '${{ needs.build.outputs.app_version }}'" >> ${pipeline_file}
  # helm_timeout
  if [ -n "$(echo "${env_params}" | yq eval '.helm_timeout')" ]; then
    echo "  helm_timeout: $(echo "${env_params}" | yq eval '.helm_timeout')" >> ${pipeline_file}
  fi
  # helm_dir
  if [ -n "$(echo "${env_params}" | yq eval '.helm_dir')" ]; then
    echo "  helm_dir: $(echo "${env_params}" | yq eval '.helm_dir')" >> ${pipeline_file}
  fi
  # helm_additional_args
  if [ -n "$(echo "${env_params}" | yq eval '.helm_additional_args')" ]; then
    echo "  helm_additional_args: $(echo "${env_params}" | yq eval '.helm_additional_args')" >> ${pipeline_file}
  fi

done

# Delete the build-test-and-deploy workflow when it's all done
#  yq -i 'del(.workflows.build-test-and-deploy)' .circleci/config.yml

}

migrate_node_deployment_jobs() {
  yq -i 'del(.workflows[] | select(.key | contains("deploy"))' .circleci/config.yml
  yq -i 'del(.workflows | with_entries(select(.key | contains("build"))))' .circleci/config.yml
  yq -i 'del(.workflows | with_entries(select(.key | contains("test"))))' .circleci/config.yml
  mkdir -p .github/workflows
  gh api repos/ministryofjustice/hmpps-template-typescript/contents/.github/workflows/pipeline.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/pipeline.yml
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

# backup circleCC config
cp .circleci/config.yml .circleci/config.yml.bak.$(date +%Y%m%d_%H%M%S)

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
