import sys
import json

def eprint(*args, **kwargs):
  print(*args, file=sys.stderr, **kwargs)

def main():
  if len(sys.argv)<2:
    eprint('Usage: python3 auditjson_to_sarif.py <<input.json>> [-o output.json]')
    sys.exit(1)

  # Default for output file if required
  args=sys.argv
  input_file=args[1]
  output_file=f"{args[1].split('.')[0]}.sarif"
  for each_arg in args:
    if each_arg=='-o' and len(args)>(args.index('-o')+1):
      output_file=args[args.index('-o')+1]

  # Build the file framework
  output_dict={ 
    "version": "2.1.0",
    "$schema": "https://schemastore.azurewebsites.net/schemas/json/sarif-2.1.0-rtm.4.json",
    "runs": [
        {
          "tool": {
            "driver": {
              "name": "npx audit-ci@^7"
          }
        }
      }
    ],
    "results": [],  
    "artifacts": []
  } 

  # Populate the results
  result_list=[]
  result_dict={}
  try:
    with open(input_file) as f:
      results=json.load(f)
    f.close()
    if 'advisories' not in results:
      eprint("No advisories in this json file - assuming it's OK") 
    else:
      results_dict=results['advisories']
  except:
    eprint("Encountered an error - please check the json file")
    sys.exit(1)
  
  for each_result_key in results_dict.keys():
    this_result=results_dict[each_result_key]
    result_dict={
      'ruleID': this_result['name'],
      'level': this_result['severity'],
      'message': json.dumps(this_result).replace(',',',\n')
    }
    result_list.append(result_dict)
  output_dict['results']=result_list

  with open(output_file,'w') as f:
    json.dump(output_dict, f)
  f.close()

if __name__ == '__main__':
  main()