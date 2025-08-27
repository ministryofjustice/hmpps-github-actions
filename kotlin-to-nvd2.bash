#!/bin/bash
#
# To be run from inside the github project that you would like to create / update the OWASP security job; expected usage is:
# ../hmpps-github-actions/kotlin-to-nvd2.bash
#
# This will add the appropriate configurations to:
# - build.gradle.kts
# - security_owasp.yml
#
# If the configuration is already there, it won't add it again
#
# Requires yq (v4) to be installed and hmpps-github-actions to be checked out (and up to date) at the same level as this
# github project. 
#


function update_security_owasp_yml() {
  yml_file=".github/workflows/security_owasp.yml"
  if [ $(yq '.jobs."security-kotlin-owasp-check".with.nvd_feed_version' ${yml_file}) != "2" ] ; 
  then 
    yq e -i '.jobs."security-kotlin-owasp-check".with.nvd_feed_version = "2"' ${yml_file}
    echo "Added nvd_feed_version: 2 to ${yml_file}"
  else
    echo "nvd_feed_version: 2 already in ${yml_file} - no action taken"
  fi 
}

function update_build_gradle_kts() {
  FILE='build.gradle.kts'
  gsed -i -E -e 's/spring-boot"\) version "[3-9].[0-9]{1,}.[0-9]{1,}(-beta)?(-beta-[1-9])?"$/spring-boot") version "9.0.0"/' ${FILE}
}

update_security_owasp_yml
update_build_gradle_kts
