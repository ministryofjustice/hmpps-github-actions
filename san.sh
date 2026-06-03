#!/bin/bash

# Fetch the JSON data using curl
response=$(curl -s "https://service-catalogue.hmpps.service.justice.gov.uk/v1/components?populate=environments\&filters%5Bname%5D=hmpps-developer-portal")

# Print the raw JSON data for debugging
echo "Raw JSON response:"
echo "$response"

# Process the JSON data using jq
output=$(echo "$response" | jq -r '
  .data[0].attributes as $attributes |
  $attributes.environments | map({
    env_type: .environment_type,
    image: ($attributes.container_image + ":" + .build_image_tag)
  })
')
# Print the final JSON
echo "Processed JSON output:"
echo "$output"
