import sys
import json
import os

sev_lookup={
  'high':'error',
  'moderate':'warning',
  'low':'note'
}

def eprint(*args, **kwargs):
  print(*args, file=sys.stderr, **kwargs)

def main():
  if len(sys.argv)<2:
    eprint('Usage: python3 outdated_to_slack.py <<input.txt>> [-o output.json]')
    sys.exit(1)

  # Default for output file if required
  args=sys.argv
  input_file=args[1]
  output_file=f"{args[1].split('.')[0]}.json"
  for each_arg in args:
    if each_arg=='-o' and len(args)>(args.index('-o')+1):
      output_file=args[args.index('-o')+1]
  
  server_url=os.getenv('server_url')
  repository=os.getenv('repository')
  run_id=os.getenv('run_id')
  workflow=os.getenv('workflow')
  job=os.getenv('job')
  repository_name=os.getenv('repository_name')

  slack_template = { 
    "text": "npm outdated scan identified issues",
    "blocks": [
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": ":warning: Github Actions *npm outdated reports check* ran and identified issues"
        }
      },
      {
        "type": "rich_text",
        "elements": [
          {
            "type": "rich_text_preformatted",
            "elements": [
              {
                "type": "text",
                "text": ""
              }
            ]
          }
        ]
      },
      {
        "type": "section",
        "fields": [
          {
            "type": "mrkdwn",
            "text": f"*Workflow:*\n<{server_url}/{repository}/actions/runs/{run_id}|{workflow}>"
          },
          {
            "type": "mrkdwn",
            "text": f"*Job:*\n{job}"
          },
          {
            "type": "mrkdwn",
            "text": f"*Repo:*\n{repository}"
          },
          {
            "type": "mrkdwn",
            "text": f"*Project:*\n{repository_name}"
          }
        ]
      }
    ]
  }

  results=''
  try:
    with open(input_file) as f:
      results=f.read()
    f.close()     
  except:
    eprint("Encountered an error - please check the input file")
    sys.exit(1)
  if results:
    slack_template['blocks'][1]['elements'][0]['elements'][0]['text']=results

  with open(output_file,'w') as f:
    json.dump(slack_template, f)
  f.close()

if __name__ == '__main__':
  main()