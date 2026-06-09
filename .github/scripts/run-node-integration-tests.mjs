import { readdir } from 'node:fs/promises'
import { spawn, spawnSync } from 'node:child_process'
import { relative, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'

const MAX_SHARDS = 6
const cypressPattern = /\.cy(?:\.|$)/
const playwrightPattern = /\.spec(?:\.|$)/
const testPatterns = [cypressPattern, playwrightPattern]
const ignoredDirectories = new Set([
  '.git',
  '.hmpps-github-actions',
  'build',
  'coverage',
  'dist',
  'node_modules',
])
const childProcessOptions = { shell: false, stdio: 'inherit' }

export function parseShardConfiguration(env) {
  const shardCount = Number(env.SHARD_COUNT)
  const shardIndex = Number(env.SHARD_INDEX)

  if (!Number.isInteger(shardCount) || shardCount < 1 || shardCount > MAX_SHARDS) {
    throw new Error(`shard_count must be an integer from 1 to ${MAX_SHARDS}; received "${env.SHARD_COUNT}"`)
  }

  return { shardCount, shardIndex }
}

export function selectShard(files, shardIndex, shardCount) {
  return [...files].sort().filter((_, index) => index % shardCount === shardIndex - 1)
}

export function detectFramework(files) {
  const hasCypressTests = files.some(file => cypressPattern.test(file))
  const hasPlaywrightTests = files.some(file => playwrightPattern.test(file))

  if (!hasCypressTests && !hasPlaywrightTests) {
    throw new Error('No Cypress (.cy) or Playwright (.spec) test files were found')
  }
  if (hasCypressTests && hasPlaywrightTests) {
    throw new Error('Both Cypress (.cy) and Playwright (.spec) test files were found; parallel runs must use one framework')
  }

  return hasCypressTests ? 'cypress' : 'playwright'
}

export function cypressTestArguments(npmScript, files) {
  return ['run', npmScript, '--', '--spec', files.join(',')]
}

export function playwrightTestArguments(npmScript, shardIndex, shardCount) {
  return ['run', npmScript, '--', `--shard=${shardIndex}/${shardCount}`]
}

async function discoverTestFiles(directory, root = directory) {
  const entries = await readdir(directory, { withFileTypes: true })
  const files = []

  for (const entry of entries) {
    if (entry.isDirectory() && !ignoredDirectories.has(entry.name)) {
      files.push(...await discoverTestFiles(resolve(directory, entry.name), root))
    } else if (entry.isFile() && testPatterns.some(pattern => pattern.test(entry.name))) {
      files.push(relative(root, resolve(directory, entry.name)).split(sep).join('/'))
    }
  }

  return files
}

function runSync(command, args) {
  const result = spawnSync(command, args, childProcessOptions)
  if (result.error) throw result.error
  if (result.status !== 0) {
    const error = new Error(`${command} exited with status ${result.status ?? 1}`)
    error.exitCode = result.status ?? 1
    throw error
  }
}

function start(command, args) {
  const child = spawn(command, args, childProcessOptions)
  child.on('error', error => {
    console.error(`Failed to start ${command}:`, error)
    process.exitCode = 1
  })
  return child
}

const sleep = milliseconds => new Promise(resolvePromise => setTimeout(resolvePromise, milliseconds))

async function prepareTestArguments(npmScript, shardIndex, shardCount) {
  if (shardCount === 1) return ['run', npmScript]

  const files = await discoverTestFiles(process.cwd())
  const framework = detectFramework(files)

  if (framework === 'playwright') {
    console.log(`Running Playwright shard ${shardIndex}/${shardCount}`)
    return playwrightTestArguments(npmScript, shardIndex, shardCount)
  }

  const shardFiles = selectShard(files, shardIndex, shardCount)
  console.log(`Shard ${shardIndex}/${shardCount}: selected ${shardFiles.length} of ${files.length} Cypress test files`)

  if (shardFiles.length === 0) {
    throw new Error(`Shard ${shardIndex}/${shardCount} has no test files; reduce shard_count`)
  }

  return cypressTestArguments(npmScript, shardFiles)
}

async function main() {
  const npmScript = process.env.NPM_SCRIPT
  if (!npmScript) throw new Error('npm_script must not be empty')

  const { shardCount, shardIndex } = parseShardConfiguration(process.env)
  const wiremockPort = process.env.WIREMOCK_PORT
  const testArguments = await prepareTestArguments(npmScript, shardIndex, shardCount)
  const wiremock = start('java', ['-jar', 'wiremock.jar', '--port', wiremockPort])
  const feature = start('npm', ['run', 'start-feature'])

  try {
    await sleep(5000)
    runSync('npm', testArguments)
  } finally {
    feature.kill()
    wiremock.kill()
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch(error => {
    console.error(error.message)
    process.exitCode = error.exitCode ?? 1
  })
}
