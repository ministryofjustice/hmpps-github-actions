import sys
import json
import os
from prettytable import PrettyTable


def eprint(*args, **kwargs):
  print(*args, file=sys.stderr, **kwargs)


def generate_table(data):
  t = PrettyTable(['ID', 'Module', 'Paths', 'SeverityNum', 'Severity', 'URL'])
  t.align = 'l'
  report = ''
  rows = []
  for row in data:
    rows.append(
      [
        row.get('id'),
        row.get('module'),
        row.get('paths'),
        row.get('severity_value'),
        row.get('severity'),
        row.get('url'),
      ]
    )
  rows.sort(key=lambda x: (x[3] is None, -(x[3] or 0), x[0], x[1]))
  for row in rows:
    t.add_row(row)
  t.del_column('SeverityNum')
  table_str = str(t)
  width = len(table_str.split('\n')[0])
  title = '=== npm audit security report ==='
  report = f'\n{title.center(width)}\n'
  report += f'{table_str}'
  return report


def main():
  if len(sys.argv) < 1:
    eprint('Usage: python3 auditjson_to_slack.py <<input.json>>')
    sys.exit(1)
  # Default for output file if required
  args = sys.argv
  input_file = args[1]

  # Populate the results
  result_list = []
  try:
    with open(input_file) as f:
      results = json.load(f)
    f.close()
    if 'advisories' not in results:
      eprint("No advisories in this json file - assuming it's OK")
      results_dict = {}
    else:
      results_dict = results['advisories']
  except Exception as e:
    eprint(f'Encountered an error - please check the json file: {e}')
    sys.exit(1)

  for key, results in results_dict.items():
    module = results.get('name')
    paths = '\n'.join(results.get('nodes'))
    for source in results.get('via'):
      try:
        result_list.append(
          {
            'id': source.get('source'),
            'module': module,
            'paths': paths,
            'severity_value': source.get('cvss').get('score'),
            'severity': source.get('severity'),
            'URL': source.get('URL'),
          }
        )
      except Exception as e:
        eprint(f'Failed to parse results for {key} - {e}')

  slack_table = generate_table(result_list)
  print(f'SLACK_TXT={slack_table}')


if __name__ == '__main__':
  main()
