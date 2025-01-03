#!/bin/bash
#
migration_script_info='

CircleCI configuration migration script - version 0.2
=====================================================

This script is to be run from the repo you wish to migrate:
/bin/bash -c "$(curl -fsSL https://github.com/ministryofjustice/hmpps-github-actions/raw/refs/heads/main/migrate-repo.sh)"

This will present three options:
[1] Security workflows only - to delete all existing security workflows and replace with Github Actions OWASP / trivy and veracode workflows for
the given project type.
[2] Build/test/deployment only - to delete all existing deployment workflows and replace with the Github Actions deployment workflows for the given project type.
[3] Complete migration - to delete existing build/test/deploy and security workflows and replace with the GHA equivalent


CONSIDERATIONS
 
General
--------
Requires yq to be installed and gh to be installed (both can be done using brew install yq gh)
Note that yq will reformat your circleci yaml file so worth checking the results before raising
PRs especially if you have multi-line commands in your file.

Build/test/deploy
-----------------
The script will copy down the most recent template build/test/deployment pipeline and attempt to copy over
configurations for docker build and deployment to the environments specified in the existing circleci config.
Any other custom or specific jobs within the CircleCI workflows (eg. Snyk scans or other integration tests) 
will need to be migrated separately.

See docs/deployment-migration.md for more information.

Security
--------
The hmpps-sre-app bot needs to be added to private repositories and SECURITY_ALERTS_SLACK_CHANNEL_ID repository variable
defined - see docs/security-migration.md for more information.

Note: The security option can be run multiple times to generate different cron expressions / refresh from the template.

Deployments
-----------
The hmpps-sre-app bot needs to be added to private repositories and PROD_RELEASES_SLACK_CHANNEL (and optionally PREPROD_RELEASES_SLACK_CHANNEL) repository variable
defined - see docs/deployment-migration.md for more information.

Review
------
The script will create a backup of the existing .circleci/config.yml file before making changes.
Any custom or extra components will need to be migrated separately - please review these within the .circleci/config.yml.bak file
'

# Functions
migrate_kotlin_security_jobs() {
  yq -i 'del(.workflows.security) | del(.workflows.security-weekly) | del(.parameters.alerts-slack-channel)' .circleci/config.yml
  mkdir -p .github/workflows

  gh api repos/ministryofjustice/hmpps-template-kotlin/contents/.github/workflows/security_owasp.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_owasp.yml
  gh api repos/ministryofjustice/hmpps-template-kotlin/contents/.github/workflows/security_trivy.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_trivy.yml
  gh api repos/ministryofjustice/hmpps-template-kotlin/contents/.github/workflows/security_veracode_pipeline_scan.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_veracode_pipeline_scan.yml
  gh api repos/ministryofjustice/hmpps-template-kotlin/contents/.github/workflows/security_veracode_policy_scan.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_veracode_policy_scan.yml

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

  gh api repos/ministryofjustice/hmpps-template-typescript/contents/.github/workflows/security_npm_dependency.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_npm_dependency.yml
  gh api repos/ministryofjustice/hmpps-template-typescript/contents/.github/workflows/security_trivy.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_trivy.yml
  gh api repos/ministryofjustice/hmpps-template-typescript/contents/.github/workflows/security_veracode_pipeline_scan.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_veracode_pipeline_scan.yml
  gh api repos/ministryofjustice/hmpps-template-typescript/contents/.github/workflows/security_veracode_policy_scan.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/security_veracode_policy_scan.yml

  RANDOM_HOUR=$((RANDOM % (9 - 3 + 1) + 3))
  RANDOM_MINUTE=$((RANDOM%60))
  RANDOM_MINUTE2=$((RANDOM%60))

  for file in security_npm_dependency.yml security_trivy.yml security_veracode_pipeline_scan.yml; do
    yq -i ".on.schedule[].cron=\"$RANDOM_MINUTE $RANDOM_HOUR * * MON-FRI\" | .on.schedule[].cron line_comment=\"Every weekday at $(printf "%02d:%02d" $RANDOM_HOUR $RANDOM_MINUTE) UTC\"" .github/workflows/$file
  done

  yq -i ".on.schedule[].cron=\"$RANDOM_MINUTE2 $RANDOM_HOUR * * 1\" | .on.schedule[].cron line_comment=\"Every Monday at $(printf "%02d:%02d" $RANDOM_HOUR $RANDOM_MINUTE2) UTC\"" .github/workflows/security_veracode_policy_scan.yml
}

migrate_deployment_jobs() {

  mkdir -p .github/workflows
  pipeline_file=".github/workflows/pipeline.yml"
  # Pull down the template pipeline and remove deploy_dev
  gh api repos/ministryofjustice/hmpps-template-kotlin/contents/.github/workflows/pipeline.yml -H "Accept: application/vnd.github.v3.raw"  | grep -v  "^ *#" | yq eval 'del(.jobs.deploy_dev)' > ${pipeline_file}

  # Load the list of build / test / deploy jobs into a string
  # only build-test-deploy will be populated - the others will be added at the bottom and commented out
  all_btd_jobs=$(yq eval '.workflows | keys | map(select(test("build|test|deploy")))' .circleci/config.yml | awk '{print $2}')

  # Create a list of environments that are deployed to
  workflow_jobs=$(yq eval '.workflows.build-test-and-deploy.jobs.[]' .circleci/config.yml)
  deploy_envs=$(yq eval '.workflows.build-test-and-deploy | select(.jobs[]."hmpps/deploy_env") | .jobs[] | select(has("hmpps/deploy_env")) | ."hmpps/deploy_env".env' .circleci/config.yml)

  # BUILD modifications

  # check to see if it's multiplatform or not 
  if [ $(yq eval '.workflows.build-test-and-deploy | select(.jobs[]."hmpps/build_multiplatform_docker") | .jobs[] | select(has("hmpps/build_multiplatform_docker")) | .hmpps/build_multiplatform_docker' .circleci/config.yml) ]; then
    docker_build='build_multiplatform_docker'
  else
    docker_build='build_docker'
  fi

  # get the filters for branches
  branch_filter=$(yq eval ".workflows.build-test-and-deploy | select(.jobs[].\"hmpps/${docker_build}\") | .jobs[] | select (has(\"hmpps/${docker_build}\")) | .hmpps/${docker_build}.filters.branches.only[] " .circleci/config.yml)
  if [ -n "${branch_filter}" ]; then
    branch_filter_string=""
    nb=0
    for each_branch in $(echo $branch_filter); do
      if [ $nb -eq 0 ] ; then
        nb=1 
        else branch_filter_string="${branch_filter_string} || " 
      fi
      # check for regex in the branch filter
      if [ $(echo $each_branch | grep -c '/') -eq 1 ]; then
        if [ $(echo $each_branch | grep -c '^') -eq 1 ]; then
          # starts with
          branch_filter_string="${branch_filter_string}startsWith(github.ref, 'refs/heads/$(echo $each_branch | sed -e 's/^\///g' -e 's/\/$//g' -e 's/\\//g'  -e 's/\.\*//g' -e 's/\^//g')')"
        else
          # contains
          branch_filter_string="${branch_filter_string}contains(github.ref,'$(echo $each_branch | sed -e 's/^\///g' -e 's/\/$//g' -e 's/\\//g' -e 's/\^//g')')"
        fi
      else
        branch_filter_string="${branch_filter_string}github.ref == 'refs/heads/${each_branch}'"
      fi
    done
    echo "Branch filter string is: $branch_filter_string"
    yq eval "(.jobs.build.if) = \"${branch_filter_string}\"" -i .github/workflows/pipeline.yml
  fi

  # toggle multiplatform docker if required
  if [ $docker_build == 'build_multiplatform_docker' ]; then
    yq eval '.jobs.build.with.docker_multiplatform = true' -i .github/workflows/pipeline.yml
  else
    yq eval '.jobs.build.with.docker_multiplatform = false' -i .github/workflows/pipeline.yml
  fi

  # additional_docker_build_args
  additional_docker_build_args="$(yq eval ".workflows.build-test-and-deploy | select(.jobs[].\"hmpps/${docker_build}\") | .jobs[] | select (has(\"hmpps/${docker_build}\")) | .hmpps/${docker_build}.additional_docker_build_args " .circleci/config.yml)" 
  if [ "${additional_docker_build_args}" != 'null' ]; then
    yq eval ".jobs.build.with.additional_docker_build_args = \"${additional_docker_build_args}\"" -i .github/workflows/pipeline.yml
  fi

  # additional_docker_tag
  additional_docker_tag=$(yq eval ".workflows.build-test-and-deploy | select(.jobs[].\"hmpps/${docker_build}\") | .jobs[] | select (has(\"hmpps/${docker_build}\")) | .hmpps/${docker_build}.additional_docker_tag " .circleci/config.yml)  
  if [ "${additional_docker_tag}" != 'null' ]; then
    # little tweak to change from CIRCLE_SHA1 to github.sha
    additional_docker_tag="$(echo $additional_docker_tag | sed -e 's/\$CIRCLE_SHA1/\${{ github.sha }}/g')"
    yq eval ".jobs.build.with.additional_docker_tag = \"${additional_docker_tag}\"" -i .github/workflows/pipeline.yml
  fi

  # DEPLOY modifications
  # loop through each of the environments
  for each_env in $deploy_envs; do
    echo "Migrating deployment job for $each_env"
    env_params=$(yq eval '.workflows.build-test-and-deploy | select(.jobs[]."hmpps/deploy_env") | .jobs[] | select(has("hmpps/deploy_env")) | select(."hmpps/deploy_env".env == "'$each_env'")' .circleci/config.yml) 

  # add the parameters one at a time
    echo "  deploy_${each_env}:" >> ${pipeline_file}
    echo "    name: Deploy to the ${each_env} environment" >> ${pipeline_file}

  # branches filter
    branch_filter=$(echo "$env_params" | yq .'hmpps/deploy_env.filters.branches.only[]')
    if [ -n "${branch_filter}" ]; then
      branch_filter_string="    if: "
      nb=0
      for each_branch in $(echo $branch_filter); do
        if [ $nb -eq 0 ] ; then
          nb=1 
          else branch_filter_string="${branch_filter_string} || " 
        fi
        # check for regex in the branch filter
        if [ $(echo $each_branch | grep -c '/') -eq 1 ]; then
          if [ $(echo $each_branch | grep -c '^') -eq 1 ]; then
            # starts with
            branch_filter_string="${branch_filter_string}startsWith(github.ref, 'refs/heads/$(echo $each_branch | sed -e 's/^\///g' -e 's/\/$//g' -e 's/\\//g'  -e 's/\.\*//g' -e 's/\^//g')')"
          else
            # contains
            branch_filter_string="${branch_filter_string}contains(github.ref,'$(echo $each_branch | sed -e 's/^\///g' -e 's/\/$//g' -e 's/\\//g' -e 's/\^//g')')"
          fi
        else
          branch_filter_string="${branch_filter_string}github.ref == 'refs/heads/${each_branch}'"
        fi
      done
      echo "Branch filter string is: $branch_filter_string"
      echo "${branch_filter_string}" >> ${pipeline_file}
    fi

    # common needs
    echo "    needs:" >> ${pipeline_file}
    echo "    - build" >> ${pipeline_file}
    echo "    - helm_lint" >> ${pipeline_file}

    # additional needs for non-dev environments
    if [ {each_env} != "dev" ]; then
      needs=$(echo "${workflow_jobs}" | yq eval '.workflows.build-test-and-deploy.jobs.[]' .circleci/config.yml | yq ".request-${each_env}-approval.requires[] | select(test(\"^deploy_\"))") 
      if [ -n "${needs}" ]; then
        echo "    - ${needs}" >> ${pipeline_file}
      fi
    fi

    # rest of the workflow bits
    echo "    uses: ministryofjustice/hmpps-github-actions/.github/workflows/deploy_env.yml@v2 # WORKFLOW_VERSION" >> ${pipeline_file}
    echo "    secrets: inherit" >> ${pipeline_file}

    echo "    with:" >> ${pipeline_file}
    echo "      environment: '${each_env}'" >> ${pipeline_file}
    echo "      app_version: '\${{ needs.build.outputs.app_version }}'" >> ${pipeline_file}
    
    # optional helm_timeout
    if [ "$(echo "${env_params}" | yq eval '.hmpps/deploy_env.helm_timeout')" != 'null' ]; then
      echo "      helm_timeout: '$(echo "${env_params}" | yq eval '.hmpps/deploy_env.helm_timeout')'" >> ${pipeline_file}
    fi
    # optional  helm_dir
    if [ "$(echo "${env_params}" | yq eval '.hmpps/deploy_env.helm_dir')" != 'null' ]; then
      echo "      helm_dir: '$(echo "${env_params}" | yq eval '.hmpps/deploy_env.helm_dir')'" >> ${pipeline_file}
    fi
    # optional  helm_additional_args
    if [ "$(echo "${env_params}" | yq eval '.hmpps/deploy_env.helm_additional_args')" != 'null' ]; then
      echo "      helm_additional_args: '$(echo "${env_params}" | yq eval '.hmpps/deploy_env.helm_additional_args')'" >> ${pipeline_file}
    fi

  done

  # Delete the build-test-and-deploy workflow when it's all done
  yq -i 'del(.workflows.build-test-and-deploy)' .circleci/config.yml
  # workaround for annoying yq !!merge tags
  sed -i.bak 's/!!merge //g' .circleci/config.yml && rm .circleci/config.yml.bak

}

## main script starts here

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

CHANNEL_ID=$(yq  -r .parameters.alerts-slack-channel.default .circleci/config.yml)
REPO_NAME="${PWD##*/}"

if [[ $CHANNEL_ID != "null" ]]; then
  echo "updating CHANNEL_ID to '$CHANNEL_ID'"  

  gh variable set SECURITY_ALERTS_SLACK_CHANNEL_ID --body "${CHANNEL_ID}" -R "ministryofjustice/${REPO_NAME}"
else
  echo "CHANNEL_ID not available in circleci config. Check value at https://github.com/ministryofjustice/${REPO_NAME}/settings/variables/actions "
fi

echo "Using '$CHANNEL_ID' as the slack channel for security alerts"


## Main menu
echo
echo "Migration script for CircleCI -> Github Actions"
echo "==============================================="
echo
echo "This script will migrate elements of CircleCI workflows to Github Actions."
echo "Please pick one of the following options by typing the corresponding number and hitting Enter:"
echo
echo "1. Migrate security workflows only"
echo "2. Migrate deployment workflows only"
echo "3. Migrate security and deployment workflows"
echo "4. Get information about this migration script"
echo "Any other selection will exit"

read -p "Enter your selection: " selection 
if [[ $selection -eq 1 ]]; then
  echo "Migrating security workflows only"
elif [[ $selection -eq 2 ]]; then
  echo "Migrating deployment workflows only"
elif [[ $selection -eq 3 ]]; then
  echo "Migrating security and deployment workflows"
elif [[ $selection -eq 4 ]]; then
  echo "${migration_script_info}"
else
  echo "Exiting"
  exit 0
fi

# backup circleCC config
cp .circleci/config.yml .circleci/config.yml.bak.$(date +%Y%m%d_%H%M%S)

if [[ -f "package.json" ]]; then
  if [[ $((selection & 1)) -ne 0 ]]; then
    echo "Migrating Node security jobs"
    migrate_node_security_jobs
  fi
elif [[ -f "build.gradle.kts" ]]; then
  if [[ $((selection & 1)) -ne 0 ]]; then
    echo "Migrating Kotlin security jobs"
    migrate_kotlin_security_jobs
  fi
else
    echo "No package.json or build.gradle.kts found."
    echo "No security jobs will be migrated"
fi

if [[ $((selection & 2)) -ne 0 ]] ; then
  echo "Migrating deployment jobs"

# we don't need to do anything particular with the deployment jobs depending on the project type
  if [[ -f "package.json" ]]; then
    migrate_deployment_jobs
    
  elif [[ -f "build.gradle.kts" ]]; then
    migrate_deployment_jobs
    
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
