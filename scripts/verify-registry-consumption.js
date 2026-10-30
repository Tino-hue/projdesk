#!/usr/bin/env node
// ProjDesk — prove that the published kernel can be consumed by a module that
// has nothing to do with this repository.
//
// The kernel is published to Mooncakes as `Tino-hue/projdesk-kernel`. This
// script resolves that package from the registry, compiles a fresh consumer
// module against it, runs it, and checks that all seven projections come out.
//
// Usage:
//   node scripts/verify-registry-consumption.js
//   node scripts/verify-registry-consumption.js 0.1.0
//   node scripts/verify-registry-consumption.js --require-published 0.1.0
//
// The version defaults to the one in `moonbit/moon.mod`. When that version has
// not been published yet the script says so and stops, unless
// `--require-published` is given.

import { spawnSync } from 'child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync } from 'fs';
import { tmpdir } from 'os';
import { join, dirname, resolve } from 'path';
import { fileURLToPath } from 'url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const MODULE = 'Tino-hue/projdesk-kernel';
const PROJECTIONS = ['jsonSchema', 'openapi', 'sql', 'graphql', 'typescript', 'zod', 'prisma'];
// The typed round-trip failure: what went wrong, and which source broke.
const FAILURE_KIND = 'parse_error';
const FAILURE_STAGE = 'printed';

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(1);
}

function moon(args, cwd) {
  const result = spawnSync('moon', args, { cwd, encoding: 'utf8', shell: false });
  if (result.error) {
    if (result.error.code === 'ENOENT') {
      fail('the MoonBit toolchain is not on PATH (install it, then `moon version`)');
    }
    fail(`could not run moon ${args.join(' ')}: ${result.error.message}`);
  }
  return { status: result.status, stdout: result.stdout ?? '', stderr: result.stderr ?? '' };
}

function versionInMoonMod() {
  const text = readFileSync(join(ROOT, 'moonbit', 'moon.mod'), 'utf8');
  const match = text.match(/^\s*version\s*=\s*"([^"]+)"/m);
  if (!match) fail('no version found in moonbit/moon.mod');
  return match[1];
}

// `moon view <module>@<version> --json` has three possible outcomes and they
// must not be confused:
//   published    — the registry says this version exists
//   missing      — the registry answered, and this version is not there
//   unreachable  — the registry could not be reached (DNS, network, outage)
// The third one is not "missing". Treating it as missing turns a registry
// outage into a silent skip, and a skip proves nothing.
function classifyView(result) {
  const out = (result.stdout || '').trim();
  if (result.status === 0 && out) {
    try {
      const parsed = JSON.parse(out);
      if (parsed.status === 'success' && parsed.result) return 'published';
      const message = (parsed.messages || []).map((m) => m.message || '').join(' ');
      if (/404|not found/i.test(message)) return 'missing';
      return 'unreachable';
    } catch {
      // fall through to the text check
    }
  }
  if (/404|not found/i.test(out + (result.stderr || ''))) return 'missing';
  return 'unreachable';
}

function sleep(ms) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

function publishedVersion(version) {
  let state = 'unreachable';
  for (let attempt = 1; attempt <= 3; attempt++) {
    state = classifyView(moon(['view', `${MODULE}@${version}`, '--json'], ROOT));
    if (state !== 'unreachable') return state;
    if (attempt < 3) {
      console.log(`  the registry did not answer (attempt ${attempt}), retrying...`);
      sleep(5000);
    }
  }
  return state;
}

// The consumer module. It is written by hand rather than by `moon new` so
// that no account is needed to check the package: the point is that anybody
// can consume the kernel, not that this project can.
function writeConsumer(dir, version) {
  mkdirSync(join(dir, 'cmd', 'demo'), { recursive: true });

  writeFileSync(
    join(dir, 'moon.mod'),
    `name = "projdesk-verify/consumer"\nversion = "0.1.0"\n\nimport {\n  "${MODULE}@${version}",\n}\n`,
  );
  writeFileSync(join(dir, 'moon.pkg'), '');
  writeFileSync(
    join(dir, 'cmd', 'demo', 'moon.pkg'),
    `import {\n  "${MODULE}/main" @projdesk,\n}\n\npkgtype(kind: "executable")\n`,
  );
  writeFileSync(
    join(dir, 'cmd', 'demo', 'main.mbt'),
    [
      'fn main {',
      '  // the kernel compiles a DSL source and projects it to all seven targets',
      '  let (projections, problems) = @projdesk.dsl_project(',
      '    "model User {\\n  id: Big @unique\\n  name: Text [shortest=1, longest=64]\\n}",',
      '  )',
      '  println(projections)',
      '  for problem in problems {',
      '    println(problem)',
      '  }',
      '  // a failure the kernel reports as a kind and a stage, not a sentence',
      '  let verdict = @projdesk.verify_roundtrip_dsl_entry(',
      '    "model T {\\n  x: Text [format=\\"a b\\"]\\n}",',
      '  )',
      '  println(verdict)',
      '}',
      '',
    ].join('\n'),
  );
}

const argv = process.argv.slice(2);
const requirePublished = argv.includes('--require-published');
const positional = argv.filter((a) => !a.startsWith('--'));
const version = positional[0] ?? versionInMoonMod();

if (argv.includes('--selftest')) {
  // The three outcomes are decided here, so they are checked here too.
  const samples = [
    ['published', { status: 0, stdout: JSON.stringify({ status: 'success', result: { version: '0.2.0' } }), stderr: '' }],
    [
      'missing',
      {
        status: 1,
        stdout: JSON.stringify({
          status: 'failure',
          result: null,
          messages: [
            {
              level: 'error',
              message:
                'registry module request failed at https://mooncakes.io/api/v0/manifest/X@9.9.9: ' +
                'HTTP status client error (404 Not Found) for url (...)',
            },
          ],
        }),
        stderr: '',
      },
    ],
    [
      'unreachable',
      { status: 1, stdout: '', stderr: 'error sending request ... dns error ... 不知道这样的主机。' },
    ],
    ['unreachable', { status: 0, stdout: '', stderr: '' }],
    ['missing', { status: 1, stdout: '', stderr: 'HTTP status client error (404 Not Found)' }],
  ];
  let bad = 0;
  for (const [expected, sample] of samples) {
    const got = classifyView(sample);
    const ok = got === expected;
    if (!ok) bad += 1;
    console.log(`  ${ok ? 'OK  ' : 'BAD '} expected ${expected.padEnd(11)} got ${got}`);
  }
  console.log(bad === 0 ? 'selftest passed.' : `selftest failed: ${bad} case(s).`);
  process.exit(bad === 0 ? 0 : 1);
}

console.log(`ProjDesk — registry consumption check for ${MODULE}@${version}`);

const state = publishedVersion(version);
if (state === 'missing') {
  const message = `${MODULE}@${version} is not published yet`;
  if (requirePublished) fail(message);
  console.log(`SKIP: ${message} — publish it, then run this again`);
  process.exit(0);
}
if (state === 'unreachable') {
  fail(
    `could not reach the Mooncakes registry, so it is unknown whether ` +
      `${MODULE}@${version} is published. This is a network problem, not a ` +
      `missing version — do not treat it as a skip.`,
  );
}

const dir = mkdtempSync(join(tmpdir(), 'projdesk-consumer-'));
try {
  writeConsumer(dir, version);

  // A fresh machine has no registry index yet, and the dependency cannot be
  // resolved without one. A failure here is not fatal on its own: `moon check`
  // fetches what it needs anyway.
  const update = moon(['update'], dir);
  if (update.status !== 0) {
    console.log('note: `moon update` did not succeed; continuing anyway');
  }

  const check = moon(['check', '--deny-warn'], dir);
  if (check.status !== 0) {
    console.error(check.stdout + check.stderr);
    fail('the consumer module does not compile against the published kernel');
  }

  const run = moon(['run', 'cmd/demo'], dir);
  if (run.status !== 0) {
    console.error(run.stdout + run.stderr);
    fail('the consumer module does not run against the published kernel');
  }

  const output = run.stdout + run.stderr;
  const missing = PROJECTIONS.filter((p) => !output.includes(p));
  if (missing.length > 0) {
    console.error(output);
    fail(`the published kernel did not produce: ${missing.join(', ')}`);
  }
  for (const expected of [FAILURE_KIND, FAILURE_STAGE]) {
    if (!output.includes(expected)) {
      console.error(output);
      fail(`the published kernel did not report the failure as "${expected}"`);
    }
  }
  if (output.includes('Warning') || output.includes('deprecated')) {
    console.error(output);
    fail('the consumer emitted a warning');
  }

  console.log(
    `OK: a fresh module consumed ${MODULE}@${version}, got all ${PROJECTIONS.length} projections ` +
      `and a typed failure (${FAILURE_KIND}/${FAILURE_STAGE})`,
  );
} finally {
  rmSync(dir, { recursive: true, force: true });
}
