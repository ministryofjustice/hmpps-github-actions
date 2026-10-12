require 'yaml'
require 'json'
require 'open3'
require 'tmpdir'
require 'minitest/autorun'

class SecurityWorkflowTest < Minitest::Test
  WORKFLOW = YAML.load_file(File.expand_path('../.github/workflows/security_scan.yml', __dir__))
  DEFAULTS = (WORKFLOW['on'] || WORKFLOW[true])['workflow_call']['inputs'].transform_values { |input| input['default'] }
  STARTED = '2026-10-12T10:00:00Z'

  def execute(job, environment = {}, prefix = '')
    script = WORKFLOW['jobs'][job]['steps'].find { |step| step['run'] }['run']
    Open3.capture3(environment, 'bash', '-e', '-o', 'pipefail', '-c', prefix + script)
  end

  def test_configuration
    cases = [
      [{}, false],
      [{'codeql' => true, 'languages' => 'javascript-typescript'}, true],
      [{'codeql_source' => true, 'languages' => 'java-kotlin'}, true],
      [{'codeql_actions' => true}, true],
      [{'codeql' => true}, false],
      [{'codeql_source' => true, 'languages' => '   '}, false],
      [{'snyk' => true}, true],
      [{'snyk' => true, 'snyk_scan_type' => 'image'}, false],
      [{'snyk' => true, 'snyk_scan_type' => 'image', 'snyk_image_ref' => 'ghcr.io/org/app:sha'}, true],
      [{'npm_audit' => true}, true],
      [{'owasp' => true}, true],
      [{'snyk' => true, 'veracode_pipeline' => true}, false],
      [{'snyk' => true, 'veracode_policy' => true}, false],
      [{'snyk' => true, 'severity_threshold' => 'invalid'}, false]
    ]
    cases.each do |overrides, expected|
      stdout, stderr, result = execute('configure', 'INPUTS' => JSON.generate(DEFAULTS.merge(overrides)))
      assert_equal expected, result.success?, "#{overrides}: #{stdout} #{stderr}"
    end
  end

  def test_gate
    base = {
      'CONFIGURATION_RESULT' => 'success', 'SUMMARY_RESULT' => 'success',
      'FAILED_SCANS' => '0', 'FINDINGS' => '0', 'REVIEW_RESULT' => 'skipped',
      'GITHUB_OUTPUT' => '/dev/null'
    }
    cases = [
      [{}, true],
      [{'FINDINGS' => '6', 'REVIEW_RESULT' => 'success'}, true],
      [{'FINDINGS' => '6'}, false],
      [{'FINDINGS' => '6', 'REVIEW_RESULT' => 'failure'}, false],
      [{'FAILED_SCANS' => '1', 'REVIEW_RESULT' => 'success'}, false],
      [{'SUMMARY_RESULT' => 'failure'}, false],
      [{'CONFIGURATION_RESULT' => 'failure'}, false],
      [{'FAILED_SCANS' => ''}, false]
    ]
    cases.each do |overrides, expected|
      stdout, stderr, result = execute('gate', base.merge(overrides))
      assert_equal expected, result.success?, "#{overrides}: #{stdout} #{stderr}"
    end
  end

  def analysis(tool, category, overrides = {})
    {'tool' => {'name' => tool}, 'category' => category, 'commit_sha' => 'current',
     'created_at' => '2026-10-12T10:01:00Z', 'error' => ''}.merge(overrides)
  end

  def alert(scan, severity = 'high', overrides = {})
    {'tool' => scan['tool'], 'rule' => {'security_severity_level' => severity},
     'most_recent_instance' => {'category' => scan['category'], 'commit_sha' => 'current'},
     'number' => 1, 'html_url' => 'https://github.com/org/repo/security/code-scanning/1'}.merge(overrides)
  end

  def summary(inputs, analyses, alerts = [], job_results = {}, api_failure = false)
    mock = <<~BASH
      gh() {
        if [[ "$API_FAILURE" == 'true' ]]; then return 1; fi
        case "$*" in
          *'/actions/runs/'*) printf '%s\n' "$STARTED" ;;
          *'/code-scanning/analyses'*) printf '%s\n' "$ANALYSES" ;;
          *'/code-scanning/alerts'*) printf '%s\n' "$ALERTS" ;;
          *) return 1 ;;
        esac
      }
      sleep() { :; }
    BASH
    jobs = %w[configure codeql_source codeql_actions snyk npm_audit owasp].to_h { |name| [name, {'result' => 'success'}] }
    job_results.each { |name, result| jobs[name]['result'] = result }
    Dir.mktmpdir('security-workflow-test') do |directory|
      environment = {
        'INPUTS' => JSON.generate(DEFAULTS.merge(inputs)), 'SCAN_JOBS' => JSON.generate(jobs),
        'REPOSITORY' => 'org/repo', 'REF' => 'refs/heads/test', 'COMMIT_SHA' => 'current',
        'RUN_ID' => '1', 'STARTED' => STARTED, 'ANALYSES' => JSON.generate([analyses]),
        'ALERTS' => JSON.generate([alerts]), 'API_FAILURE' => api_failure.to_s,
        'GITHUB_OUTPUT' => File.join(directory, 'outputs'),
        'GITHUB_STEP_SUMMARY' => File.join(directory, 'summary')
      }
      script = WORKFLOW['jobs']['summary']['steps'].first['run']
      stdout, stderr, result = Open3.capture3(environment, 'bash', '-e', '-o', 'pipefail', '-c', mock + script, chdir: directory)
      return nil unless result.success? || !api_failure
      assert result.success?, "#{stdout} #{stderr}"
      JSON.parse(File.read(File.join(directory, 'security-results.json')))
    end
  end

  def test_summary_distinguishes_codeql_scans
    source = analysis('CodeQL', 'hmpps-security/codeql-source')
    actions = analysis('CodeQL', 'hmpps-security/codeql-actions')
    combined = summary({'codeql' => true}, [source, actions], [alert(source), alert(actions)])
    assert_empty combined['failed']
    assert_equal 2, combined['findings'].length
    only_actions = summary({'codeql_actions' => true}, [source, actions], [alert(source), alert(actions)])
    assert_empty only_actions['failed']
    assert_equal 1, only_actions['findings'].length
    missing_actions = summary({'codeql' => true}, [source])
    assert_equal ['codeql_actions'], missing_actions['failed']
  end

  def test_summary_accepts_actual_snyk_category
    snyk = analysis('Snyk Open Source', 'Snyk/Open Source/app/0')
    result = summary({'snyk' => true}, [snyk], [alert(snyk), alert(snyk, 'medium')])
    assert_empty result['failed']
    assert_equal 1, result['findings'].length
    assert_equal 2, summary({'snyk' => true, 'severity_threshold' => 'medium'}, [snyk], [alert(snyk), alert(snyk, 'medium')])['findings'].length
  end

  def test_summary_rejects_stale_missing_failed_and_errored_scans
    snyk = analysis('Snyk Open Source', 'Snyk/Open Source/app/0')
    variants = [[], [snyk.merge('commit_sha' => 'old')], [snyk.merge('created_at' => '2026-10-12T09:00:00Z')], [snyk.merge('error' => 'Scan failed')]]
    variants.each { |analyses| assert_equal ['snyk'], summary({'snyk' => true}, analyses)['failed'] }
    assert_equal ['snyk'], summary({'snyk' => true}, [snyk], [], {'snyk' => 'failure'})['failed']
    assert_equal ['snyk'], summary({'snyk' => true}, [snyk], [], {'snyk' => 'skipped'})['failed']
  end

  def test_summary_handles_npm_owasp_and_generic_severity
    npm = analysis('npm audit', 'npm-dependency-check')
    owasp = analysis('OWASP', 'gradle-owasp-dependency-check')
    result = summary({'npm_audit' => true, 'owasp' => true}, [npm, owasp], [alert(npm), alert(owasp)])
    assert_empty result['failed']
    assert_equal 2, result['findings'].length
    actions = analysis('CodeQL', 'hmpps-security/codeql-actions')
    generic = alert(actions, nil, 'rule' => {'severity' => 'error'})
    assert_equal 1, summary({'codeql_actions' => true}, [actions], [generic])['findings'].length
  end

  def test_api_failure_does_not_produce_a_clean_summary
    assert_nil summary({'snyk' => true}, [], [], {}, true)
  end

  def test_embedded_shell_syntax
    WORKFLOW['jobs'].each do |name, job|
      job.fetch('steps', []).each do |step|
        next unless step['run']
        stdout, stderr, result = Open3.capture3('bash', '-n', stdin_data: step['run'])
        assert result.success?, "#{name}: #{stdout} #{stderr}"
      end
    end
  end
end