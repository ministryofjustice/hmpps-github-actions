## 0.1
First release

## 0.2
Finessing of workflows - better Sarif file for typescript reports

If no Slack channel is included, no messages will be sent.


## v0.3
Semantic versioning

This also uses inherited secrets in the template workflows to avoid having to add the local secrets to each one.

## v0.7
Inline python scripts to avoid having to run them locally (benefit: keeps any fixes/improvements inside the shared actions)

## v0.7.1
Change to `.github/workflows/security_veracode_policy_scan.yml`. Updated scan identifier string so it now includes the github action ID, github branch, github commit sha. This makes it easier to link the veracode scan results with a commit in the dev portal.