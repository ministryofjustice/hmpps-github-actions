import assert from 'node:assert/strict'
import test from 'node:test'

import {
  cypressTestArguments,
  detectFramework,
  parseShardConfiguration,
  playwrightTestArguments,
  selectShard,
} from './run-node-integration-tests.mjs'

test('rejects shard counts above the supported maximum', () => {
  assert.throws(() => parseShardConfiguration({ SHARD_COUNT: '7', SHARD_INDEX: '1' }), /shard_count must be an integer from 1 to 6/)
})

test('selects a deterministic shard after sorting files', () => {
  assert.deepEqual(selectShard(['c.spec.ts', 'a.spec.ts', 'b.spec.ts'], 2, 2), ['b.spec.ts'])
})

test('detects Cypress and Playwright files', () => {
  assert.equal(detectFramework(['integration/example.cy.ts']), 'cypress')
  assert.equal(detectFramework(['integration/example.spec.ts']), 'playwright')
})

test('rejects mixed test frameworks', () => {
  assert.throws(() => detectFramework(['a.cy.ts', 'b.spec.ts']), /Both Cypress/)
})

test('builds Cypress npm arguments', () => {
  assert.deepEqual(
    cypressTestArguments('int-test', ['a.cy.ts', 'b.cy.ts']),
    ['run', 'int-test', '--', '--spec', 'a.cy.ts,b.cy.ts'],
  )
})

test('builds Playwright npm arguments using native sharding', () => {
  assert.deepEqual(
    playwrightTestArguments('int-test', 2, 3),
    ['run', 'int-test', '--', '--shard=2/3'],
  )
})
