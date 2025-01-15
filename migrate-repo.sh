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
[2] Build/test/deployment only - to add existing deployment workflows for the given project tiype to GHA and remove from CircleCI configuration.
[3] Combined migration - to add existing build/test/deploy and security workflows to GHA and remove from CircleCI configuration.


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

# this applies to both templates (project type is $1) but has custom elements depending on the project type
migrate_deployment_jobs() {

  mkdir -p .github/workflows
  pipeline_file=".github/workflows/pipeline.yml"
  # Pull down the template pipeline and remove deploy_dev
  echo "Migrating using hmpps-template-$1 template"

  gh api repos/ministryofjustice/hmpps-template-$1/contents/.github/workflows/pipeline.yml -H "Accept: application/vnd.github.v3.raw"  | grep -v  "^ *#" | yq eval 'del(.jobs.deploy_dev)' > ${pipeline_file}

  # explode the aliases - will make the branch filtering work better in the long run
  yq eval 'explode(.)' -i .circleci/config.yml
  
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
  duplicate_envs=""
  echo -n "Migrating deployment job for: "
  for each_env in $deploy_envs; do
    echo -n "$each_env .. "
    env_params=$(yq eval '.workflows.build-test-and-deploy | select(.jobs[]."hmpps/deploy_env") | .jobs[] | select(has("hmpps/deploy_env")) | select(."hmpps/deploy_env".env == "'$each_env'")' .circleci/config.yml) 

  # identify when the environment has two deployments (normally feature/main)
    if [ $(echo "$env_params" | grep -c 'hmpps/deploy_env') -gt 1 ]; then
      duplicate_envs+="${each_env}\n"
    fi

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
  # Finish the line
  echo; echo

  # Warning summary for multiple deployments
  if [ -n "${duplicate_envs}" ]; then
    echo "WARNING: Duplicate environments found in the CircleCI config (likely due to separate"
    echo "-------  deployments for feature/main branches)."
    echo -e "${duplicate_envs} " | sort | uniq -d | awk '{print "         - " $1}'
    echo 
    echo "         This will need to be resolved manually by renaming the job IDs within pipeline.yml" 
    echo "         to ensure they are unique, and applying the appropriate branch filters and 'needs' values to each job."
    echo
  fi

  ## Custom executor modifications

  # check for node_redis first of all
  node_redis_executors=$(yq eval '.jobs | with_entries(select(.value.executor.name == "hmpps/node_redis")) | keys[]' .circleci/config.yml)

  if [ -n "$node_redis_executors" ]
    then for each_executor in $node_redis_executors; do
      # integration_test - copy the workflow from github actions and and change the reference in the pipeline
      if [ ${each_executor} = "integration_test" ] ; then
        # copy the workflow down
        gh api repos/ministryofjustice/hmpps-github-actions/contents/.github/workflows/node_integration_tests.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/node_integration_tests_redis.yml
        # modify the workflow to include the service
        yq eval '.jobs.integration_test |= {"runs-on": .runs-on, "services": {"redis": {"image": "redis:7.0", "ports": ["6379:6379"], "options": "--health-cmd=\"redis-cli ping\" --health-interval=10s --health-timeout=5s --health-retries=5"}}, "steps": .steps}' -i .github/workflows/node_integration_tests_redis.yml
        # refer to the local workflow in the pipeline
        yq eval '.jobs.node_integration_tests.uses = "./.github/workflows/node_integration_tests_redis.yml"' -i .github/workflows/pipeline.yml
        echo
        echo "WARNING: template .github/workflows/node_integration_tests_redis.yml created for node/redis integration test"
        echo "-------  This will require manual modification to match the integration test within .circleci/config.yml"
        echo

      # unit_test - copy the workflow from github actions and and change the reference in the pipeline
      elif [ ${each_executor} = "unit_test" ] ; then
        # copy the workflow down
        gh api repos/ministryofjustice/hmpps-github-actions/contents/.github/workflows/node_unit_tests.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/node_unit_tests_redis.yml
        # modify the workflow to include the service
        yq eval '.jobs.node-unit-test |= {"runs-on": .runs-on, "services": {"redis": {"image": "redis:7.0", "ports": ["6379:6379"], "options": "--health-cmd=\"redis-cli ping\" --health-interval=10s --health-timeout=5s --health-retries=5"}}, "steps": .steps}' -i .github/workflows/node_unit_tests_redis.yml
        # refer to the local workflow in the pipeline
        yq eval '.jobs.node_unit_tests.uses = "./.github/workflows/node_unit_tests_redis.yml"' -i .github/workflows/pipeline.yml
        # Remove the ''
        echo "WARNING: .github/workflows/node_unit_tests_redis.yml created for node unit tests including redis."
        echo "-------  This will require manual modification to match the unit test within .circleci/config.yml"
      
      else
        echo "WARNING: Found node_redis executor ${each_executor} but no matching workflow in hmpps-github-actions"
        echo "-------  Creating a placeholder workflow for ${each_executor} in .github/workflows/node_${each_executor}_redis.yml"
        echo "         This will require manual modification to match the executor within .circleci/config.yml"
        echo "         It will also need a reference to this workflow to be added in .github/workflows/pipeline.yml"
        # copy down node_unit_tests as a template since it's simplest
        gh api repos/ministryofjustice/hmpps-github-actions/contents/.github/workflows/node_unit_tests.yml -H "Accept: application/vnd.github.v3.raw" > .github/workflows/node_${each_executor}_redis.yml
        yq eval '.jobs.node-unit-test |= {"runs-on": .runs-on, "services": {"redis": {"image": "redis:7.0", "ports": ["6379:6379"], "options": "--health-cmd=\"redis-cli ping\" --health-interval=10s --health-timeout=5s --health-retries=5"}}, "steps": .steps}' -i .github/workflows/node_${each_executor}_redis.yml
        # do a bit of tidying up of the file
        yq eval 'del(.jobs[].steps[] | select(.name == "fail the action if the tests failed") | .style="fail the action if the tests failed")' -i .github/workflows/node_${each_executor}_redis.yml
        yq eval 'del(.jobs[].steps[] | select(.id == "unit-tests") | .style="unit-tests")' -i .github/workflows/node_${each_executor}_redis.yml
      fi
    done
  fi
  

  
  # Delete the build-test-and-deploy workflow when it's all done
  yq -i 'del(.workflows.build-test-and-deploy)' .circleci/config.yml

  # Replace 'WORKFLOW_VERSION' with 'LOCAL_VERSION' for local workflows
  sed -i.bak 's|\(uses: ./.github/workflows.*\)# WORKFLOW_VERSION|\1# LOCAL_VERSION|' .github/workflows/pipeline.yml && rm .github/workflows/pipeline.yml.bak
  # workaround for annoying yq !!merge tags
  sed -i.bak 's/!!merge //g' .circleci/config.yml && rm .circleci/config.yml.bak

  echo
  echo "Summary of deployment migration:"
  echo "==============================="
  echo "  - A pipeline.yml file has been created in .github/workflows based on build-test-deploy in .circleci/config.yml"
  echo "  - Please refer to the backup file to identify the jobs that still require migration"
  echo "  - See above for warnings about executor jobs that will require configuration/manual migration"
  echo "  - Also see above for warnings about duplicate environments in the CircleCI config"
  echo "  - Finally, please review the pipeline and modify as required to ensure that it will behave as expected"
  echo
  echo "Backup file: ${backup_file}"
  echo
  echo "Please contact the SRE team (#ask-prisons-sre) for assistance with any tasks that need to be migrateed."

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
  echo "${migration_script_info}" | less
else
  echo "Exiting"
  exit 0
fi

# backup circleCC config
backup_file=".circleci/config.yml.bak.$(date +%Y%m%d_%H%M%S)"
cp .circleci/config.yml ${backup_file}

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

# the same function can be used for both repo types - just with a couple of tweaks
  if [[ -f "package.json" ]]; then
    migrate_deployment_jobs "typescript"
    
  elif [[ -f "build.gradle.kts" ]]; then
    migrate_deployment_jobs "kotlin"
    
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
