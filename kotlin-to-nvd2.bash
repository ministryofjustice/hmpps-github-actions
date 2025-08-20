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
    yq e -i '.jobs."security-kotlin-owasp-check".with.nvd_feed_version = 2' ${yml_file}
    echo "Added nvd_feed_version: 2 to ${yml_file}"
  else
    echo "nvd_feed_version: 2 already in ${yml_file} - no action taken"
  fi 
}

function update_build_gradle_kts() {
  FILE='build.gradle.kts'
  PLUGIN_LINE='  id("org.owasp.dependencycheck") version "12.1.3"'
  DEPENDENCY_BLOCK='dependencyCheck {\n  nvd.datafeedUrl = "file:///opt/vulnz/cache"\n}'

  # 1. Check and fix plugin version
  echo "Checking for dependencyCheck plugin version"
  
  awk -v plugin='  id("org.owasp.dependencycheck") version "12.1.3"' '
  BEGIN {
    step = 0 
    found = 0
  }
  # change to step 1 when we are at the plugins stage
  {
    if ($0 ~ /plugins[[:space:]]*{/) {
      print
      step = 1
      next
    }
    if (step==1){
    # Check for existing plugin line
      if ($0 ~ /id\(\"org\.owasp\.dependencycheck\"\)/) {
        found = 1
        # Replace incorrect version
        if ($0 !~ /version "12\.1\.3"/) {
          sub(/version "[^"]+"/, "version \"12.1.3\"")
        }
      }
      if (found==0 && $0 ~ /}/) {
        step = 2
        print plugin
        print
        next
      }
    }
    print
  }
  ' "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"


  # 2. Check and add dependencyCheck block
  echo "Checking for dependencyCheck feed configuration"
  if ! grep -q 'dependencyCheck {' "$FILE"; then
    echo "Adding dependencyCheck block..."
    echo -e "\n$DEPENDENCY_BLOCK" >> "$FILE"
  else
    echo "dependencyCheck block already exists - no action taken"
  fi

}

update_security_owasp_yml
update_build_gradle_kts
