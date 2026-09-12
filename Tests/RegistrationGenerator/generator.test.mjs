import assert from 'node:assert/strict';
import { mkdtemp, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const repository = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const generator = path.join(repository, 'Scripts/generate-component-registration.mjs');

async function makeFixture() {
  return mkdtemp(path.join(tmpdir(), 'swiftwui-registration-'));
}

function runGenerator(configPath) {
  return spawnSync(process.execPath, [generator, configPath], {
    cwd: repository,
    encoding: 'utf8',
  });
}

async function findSwiftWUIModules() {
  const build = path.join(repository, '.build');
  const candidates = [path.join(build, 'debug', 'Modules')];
  for (const entry of await readdir(build, { withFileTypes: true })) {
    if (entry.isDirectory()) candidates.push(path.join(build, entry.name, 'debug', 'Modules'));
  }
  for (const candidate of candidates) {
    try {
      const entries = await readdir(candidate);
      if (entries.some((entry) => entry.startsWith('SwiftWUI.swiftmodule'))) return candidate;
    } catch {
      // Candidate is for a different SwiftPM layout.
    }
  }
  throw new Error('SwiftWUI debug module not found; run swift test before this Node suite');
}

test('generates compilable public witnesses with Swift-safe literals and is idempotent', async () => {
  const root = await makeFixture();
  try {
    const sourcePath = path.join(root, 'PublicCounter.swift');
    const configPath = path.join(root, 'components.json');
    await writeFile(sourcePath, `
import SwiftWUI

@MainActor
public struct PublicCounter: Tag {
    @State private var count = 0
    @Environment(\\.routeInfo) private var route

    public init() {}
    public var body: some Tag { Text("\\(route.path):\\(count)") }
}
`.trimStart());
    await writeFile(configPath, JSON.stringify({
      components: [{
        file: 'PublicCounter.swift',
        type: 'PublicCounter',
        access: 'public',
        identifier: 'public"\\(danger)\n\b\u2028😀',
        state: [{ property: 'count', id: 'count"\\(\t\f' }],
        environment: ['route'],
      }],
    }));

    const firstRun = runGenerator(configPath);
    assert.equal(firstRun.status, 0, firstRun.stderr);
    const first = await readFile(sourcePath, 'utf8');
    assert.match(first, /public static var componentIdentifier/);
    assert.match(first, /public func registerProperties/);
    assert.ok(first.includes('\\\\(danger)'));
    assert.ok(first.includes('\\n\\u{8}\\u{2028}😀'));
    assert.ok(first.includes('stableID: "count\\"\\\\(\\t\\u{C}"'));

    const secondRun = runGenerator(configPath);
    assert.equal(secondRun.status, 0, secondRun.stderr);
    assert.equal(await readFile(sourcePath, 'utf8'), first);
    assert.equal(first.match(/swiftwui-registration:PublicCounter:begin/g)?.length, 1);

    const modules = await findSwiftWUIModules();
    const compilerArguments = [
      '-typecheck', '-swift-version', '6', '-default-isolation', 'MainActor',
      '-module-cache-path', path.join(root, 'module-cache'),
      '-I', modules, sourcePath,
    ];
    const sdk = spawnSync('xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { encoding: 'utf8' });
    if (sdk.status === 0) compilerArguments.unshift('-sdk', sdk.stdout.trim());
    const typecheck = spawnSync('swiftc', compilerArguments, { cwd: repository, encoding: 'utf8' });
    assert.equal(typecheck.status, 0,
      `${typecheck.error ?? ''}\nstdout:\n${typecheck.stdout}\nstderr:\n${typecheck.stderr}`);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test('rejects duplicate component types and identifiers before changing sources', async () => {
  const cases = [
    {
      name: 'type',
      components: [
        { file: 'A.swift', type: 'Counter', identifier: 'a' },
        { file: 'B.swift', type: 'Counter', identifier: 'b' },
      ],
      message: /Duplicate component type/,
    },
    {
      name: 'identifier',
      components: [
        { file: 'A.swift', type: 'CounterA', identifier: 'same' },
        { file: 'B.swift', type: 'CounterB', identifier: 'same' },
      ],
      message: /Duplicate component identifier/,
    },
  ];

  for (const fixture of cases) {
    const root = await makeFixture();
    try {
      const originalA = 'struct CounterA {}\n';
      const originalB = 'struct CounterB {}\n';
      await writeFile(path.join(root, 'A.swift'), originalA);
      await writeFile(path.join(root, 'B.swift'), originalB);
      const configPath = path.join(root, `${fixture.name}.json`);
      await writeFile(configPath, JSON.stringify({ components: fixture.components }));

      const result = runGenerator(configPath);
      assert.notEqual(result.status, 0);
      assert.match(result.stderr, fixture.message);
      assert.equal(await readFile(path.join(root, 'A.swift'), 'utf8'), originalA);
      assert.equal(await readFile(path.join(root, 'B.swift'), 'utf8'), originalB);
    } finally {
      await rm(root, { recursive: true, force: true });
    }
  }
});

test('rejects duplicate state IDs, mixed property ownership, and repeated markers', async () => {
  const root = await makeFixture();
  try {
    const sourcePath = path.join(root, 'Counter.swift');
    const configPath = path.join(root, 'components.json');
    const cases = [
      {
        source: 'struct Counter {}\n',
        component: {
          file: 'Counter.swift', type: 'Counter', identifier: 'counter',
          state: [{ property: 'first', id: 'value' }, { property: 'second', id: 'value' }],
        },
        message: /Duplicate state identifier/,
      },
      {
        source: 'struct Counter {}\n',
        component: {
          file: 'Counter.swift', type: 'Counter', identifier: 'counter',
          state: ['value'], environment: ['value'],
        },
        message: /Duplicate registered property/,
      },
      {
        source: `struct Counter {}
// swiftwui-registration:Counter:begin
// swiftwui-registration:Counter:begin
// swiftwui-registration:Counter:end
`,
        component: { file: 'Counter.swift', type: 'Counter', identifier: 'counter' },
        message: /Duplicate registration markers/,
      },
    ];

    for (const fixture of cases) {
      await writeFile(sourcePath, fixture.source);
      await writeFile(configPath, JSON.stringify({ components: [fixture.component] }));
      const result = runGenerator(configPath);
      assert.notEqual(result.status, 0);
      assert.match(result.stderr, fixture.message);
      assert.equal(await readFile(sourcePath, 'utf8'), fixture.source);
    }
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
