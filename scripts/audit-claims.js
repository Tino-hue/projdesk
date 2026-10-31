#!/usr/bin/env node
// Check that every number the documents state matches the code.
//
// The README, the proposal and the demo script quote line counts, test counts
// and export counts. Those are the numbers a reviewer is most likely to try
// to reproduce, and a number that has drifted is worse than no number at all.
//
// Usage: node scripts/audit-claims.js
// Exits non-zero when a claim does not match.
import { readFileSync, readdirSync, statSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const MAIN = join(ROOT, 'moonbit', 'main');

const lines = (p) => readFileSync(p, 'utf8').split('\n').length - 1;
const mbtFiles = readdirSync(MAIN).filter((f) => f.endsWith('.mbt'));
const testFiles = mbtFiles.filter((f) => f.endsWith('_test.mbt'));
const implFiles = mbtFiles.filter((f) => !f.endsWith('_test.mbt'));

const GROUPS = {
  'DSL compiler': ['dsl_lexer.mbt', 'dsl_parser.mbt', 'dsl_expr.mbt', 'dsl_codegen.mbt',
    'dsl_printer.mbt', 'dsl_semantic.mbt', 'dsl_resolve.mbt'],
  Solver: ['solver.mbt', 'solver_propagate.mbt'],
  Migration: ['migration.mbt'],
  Equivalence: ['equiv.mbt'],
  'Round-trip': ['roundtrip.mbt'],
  'Schema solvability': ['schema_check.mbt'],
};

const groupLines = (files) => files.reduce((n, f) => n + lines(join(MAIN, f)), 0);
const engine = Object.values(GROUPS).reduce((n, g) => n + groupLines(g), 0);
const inGroup = new Set(Object.values(GROUPS).flat());
const infra = implFiles.filter((f) => !inGroup.has(f)).reduce((n, f) => n + lines(join(MAIN, f)), 0);
const impl = engine + infra;
const testCode = testFiles.reduce((n, f) => n + lines(join(MAIN, f)), 0);

// the tests are counted from the source, not remembered
const moonTests = testFiles.reduce((n, f) => {
  const text = readFileSync(join(MAIN, f), 'utf8');
  return n + (text.match(/^\s*test\s+"/gm) || []).length;
}, 0);

const exports = implFiles
  .map((f) => readFileSync(join(MAIN, f), 'utf8'))
  .join('\n')
  .match(/#export_name\("([a-z_]+)"\)/g) || [];

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    if (name === 'node_modules') continue;
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}

const webSources = walk(join(ROOT, 'web', 'src'))
  .filter((p) => /\.test\.tsx?$/.test(p))
  .map((p) => ({ path: p, text: readFileSync(p, 'utf8') }));

// vitest counts one case per `it(...)`, but `it.each(table)(...)` expands into
// one case per row of the table. Both have to be counted for the numbers in
// the documents to match what vitest reports.
const countCases = (text) => {
  const plain = (text.match(/\b(?:it|test)\s*\(/g) || []).length;
  let extra = 0;
  for (const m of text.matchAll(/\b(?:it|test)\.each\s*\(\s*([A-Za-z_$][\w$]*)/g)) {
    const name = m[1];
    const decl = text.match(new RegExp(`(?:const|let)\\s+${name}[^=]*=\\s*\\[([^\\]]*)\\]`));
    if (decl) {
      const rows = decl[1].split(',').map((s) => s.trim()).filter((s) => s && !s.startsWith('//'));
      extra += rows.length;
    }
  }
  return plain + extra;
};

const frontendTests = webSources.reduce((n, s) => n + countCases(s.text), 0);
const wasmTests = countCases(
  readFileSync(join(ROOT, 'web', 'src', 'lib', 'wasm.integration.test.ts'), 'utf8'),
);

const DOCS = ['README.md', 'SUBMISSION-TEXT.md', 'DEMO.md', 'REVIEW-ANSWERS.md'];
const text = DOCS.map((d) => readFileSync(join(ROOT, d), 'utf8')).join('\n');

const EXPECTATIONS = [
  ['4845', 'six engines', engine],
  ['6860', 'implementation total', impl],
  ['3530', 'test code', testCode],
  ['2127', 'dsl compiler', groupLines(GROUPS['DSL compiler'])],
  ['633', 'solver', groupLines(GROUPS.Solver)],
  ['569', 'migration', lines(join(MAIN, 'migration.mbt'))],
  ['229', 'equivalence', lines(join(MAIN, 'equiv.mbt'))],
  ['433', 'round-trip', lines(join(MAIN, 'roundtrip.mbt'))],
  ['854', 'schema solvability', groupLines(GROUPS['Schema solvability'])],
  ['2015', 'infrastructure', infra],
  ['276', 'MoonBit tests', moonTests],
  ['95', 'frontend tests', frontendTests],
  ['26', 'WASM integration tests', wasmTests],
  ['12 exports', 'wasm exports', exports.length],
  ['12 导出', 'wasm exports (cn)', exports.length],
];

let bad = 0;
for (const [claim, label, actual] of EXPECTATIONS) {
  const stated = Number(claim.match(/\d+/)[0]);
  const present = text.includes(claim);
  const ok = present && stated === actual;
  if (!ok) bad += 1;
  console.log(
    `  ${claim.padEnd(10)} ${label.padEnd(24)} actual=${String(actual).padEnd(6)} ${ok ? 'OK' : 'MISSING/MISMATCH'}`,
  );
}

// The declaration itself: the form asks for markdown, one page, and eight
// named fields. A truncated or padded one is worse than none.
const declaration = readFileSync(join(ROOT, 'SUBMISSION-TEXT.md'), 'utf8');
const declLines = declaration.split('\n').filter((l) => l.trim());
const declChinese = (declaration.match(/[一-鿿]/g) || []).length;
const declChecks = [
  ['is markdown', declaration.startsWith('# ') && /^## /m.test(declaration)],
  ['fits on one page', declLines.length <= 40 && declChinese <= 1300],
  ['1 project name', declaration.includes('项目名称：')],
  ['2 summary', declaration.includes('## 项目简介')],
  ['3 direction and generality', declaration.includes('## 项目方向与通用性')],
  ['4 at least three usage scenarios', declaration.includes('## 预期使用场景') &&
    (declaration.split('## 预期使用场景')[1].split('\n## ')[0].match(/^\d+\. /gm) || []).length >= 3],
  ['5 core functionality', declaration.includes('## 核心功能范围')],
  ['6 originality', declaration.includes('是否为移植项目')],
  ['7 dependency and its licence', declaration.includes('moonbitstack/moonmodel') &&
    declaration.includes('Apache-2.0')],
  ['8 repository and commits', declaration.includes('有效提交')],
  ['states the artifact hash', declaration.includes('3b4ee18b9e41aa6b')],
];
console.log();
for (const [label, ok] of declChecks) {
  if (!ok) bad += 1;
  console.log(`  ${ok ? 'OK  ' : 'BAD '} declaration: ${label}`);
}
console.log(`  (${declLines.length} non-empty lines, ${declChinese} Chinese characters)`);

console.log();
console.log(`mismatches: ${bad}`);
process.exit(bad === 0 ? 0 : 1);
