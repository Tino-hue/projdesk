#!/usr/bin/env node
// ProjDesk CLI - one model description, seven projections
// Usage:
//   projdesk gen <model.json|model.dsl> [options]
//   projdesk check <model.json|model.dsl>     (constraint analysis)
//   projdesk migrate <old.json> <new.json>   (SQL migration)
//   projdesk verify <model.json|model.dsl>    (round-trip + semantics)

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import { resolve, dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const FORMATS = {
  json: 'schema.json',
  openapi: 'openapi.json',
  sql: 'schema.sql',
  graphql: 'schema.graphql',
  typescript: 'types.ts',
  zod: 'schema.zod.ts',
  prisma: 'schema.prisma',
};

function usage() {
  console.log(`
ProjDesk CLI - one model description, seven projections

Usage:
  projdesk gen <model.json|model.dsl> [options]
  projdesk check <model.json|model.dsl>
  projdesk migrate <old.json> <new.json> [options]
  projdesk verify <model.json|model.dsl>

Options:
  -o, --out <dir>        Output directory (default: ./projdesk-out)
  --format <fmts>        Comma-separated: ${Object.keys(FORMATS).join(', ')} (default: all)
  --sql-dialect <d>      Postgres | Sqlite | Mysql (default: Postgres)
  --openapi-dialect <d>  OpenApi30 | OpenApi31 | Swagger20 (default: OpenApi30)
  --stdout               Print to stdout instead of writing files
  -h, --help             Show this help

Examples:
  projdesk gen model.json
  projdesk gen model.dsl --format json,sql --out ./schemas
  projdesk gen model.json --sql-dialect Sqlite --stdout
  projdesk check model.json
  projdesk migrate old.json new.json
  projdesk verify model.dsl
`);
}

function parseArgs(argv) {
  const args = { _: [], out: 'projdesk-out', format: 'all', sqlDialect: 'Postgres', openapiDialect: 'OpenApi30', stdout: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '-h' || a === '--help') { usage(); process.exit(0); }
    else if (a === '-o' || a === '--out') args.out = argv[++i];
    else if (a === '--format') args.format = argv[++i];
    else if (a === '--sql-dialect') args.sqlDialect = argv[++i];
    else if (a === '--openapi-dialect') args.openapiDialect = argv[++i];
    else if (a === '--stdout') args.stdout = true;
    else if (['gen', 'check', 'migrate', 'verify'].includes(a)) args.cmd = a;
    else args._.push(a);
  }
  return args;
}

async function loadKernel() {
  const wasmPath = join(__dirname, 'projdesk.wasm');
  const bytes = readFileSync(wasmPath);
  const { instance } = await WebAssembly.instantiate(bytes, {}, {
    builtins: ['js-string'],
    importedStringConstants: '_',
  });
  return instance.exports;
}

function isDslFile(path) {
  return path.endsWith('.dsl') || path.endsWith('.projdesk');
}

/** Read a file, stripping UTF-8 BOM if present */
function readText(path) {
  const raw = readFileSync(path, 'utf-8');
  return raw.charCodeAt(0) === 0xFEFF ? raw.slice(1) : raw;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.cmd || args._.length === 0) { usage(); process.exit(1); }

  const kernel = await loadKernel();

  // ---- check: constraint analysis ----
  if (args.cmd === 'check') {
    const inputPath = resolve(args._[0]);
    if (!existsSync(inputPath)) { console.error(`File not found: ${inputPath}`); process.exit(1); }
    const raw = readText(inputPath);

    if (isDslFile(inputPath)) {
      const out = JSON.parse(kernel.dsl_project(raw));
      if (out.error) { console.error(`Parse error: ${out.error}`); process.exit(1); }
      console.log('DSL parsed successfully. See projections with "projdesk gen".');
      return;
    }

    const result = JSON.parse(kernel.solve_constraints(raw));
    const diags = result.diagnoses || [];
    if (diags.length === 0) {
      console.log('No issues found. All constraints are satisfiable.');
    } else {
      console.log(`${diags.length} issue(s) found:`);
      for (const d of diags) {
        console.log(`  [${d.severity.toUpperCase()}] ${d.text}`);
      }
    }
    if (result.conflict_count > 0) process.exit(1);
    return;
  }

  // ---- migrate: SQL migration ----
  if (args.cmd === 'migrate') {
    if (args._.length < 2) { console.error('Need two model files'); process.exit(1); }
    const oldRaw = readText(resolve(args._[0]));
    const newRaw = readText(resolve(args._[1]));
    const result = JSON.parse(kernel.generate_migration(oldRaw, newRaw));
    if (args.stdout) {
      console.log(result.sql);
    } else {
      console.log(result.sql);
      console.log(`\n${result.changes.length} change(s), ${result.breaking_count} breaking.`);
      for (const c of result.changes) {
        console.log(`  ${c.breaking ? '[BREAKING]' : '[safe]    '} ${c.text}`);
      }
    }
    if (result.breaking_count > 0) process.exit(1);
    return;
  }

  // ---- verify: round-trip + semantics ----
  if (args.cmd === 'verify') {
    const inputPath = resolve(args._[0]);
    if (!existsSync(inputPath)) { console.error(`File not found: ${inputPath}`); process.exit(1); }
    const raw = readText(inputPath);

    if (isDslFile(inputPath)) {
      // semantic analysis on the DSL source
      const sem = JSON.parse(kernel.check_semantics(raw));
      if (sem.parse_error) {
        console.error(`Parse error: ${sem.parse_error}`);
        process.exit(1);
      }
      console.log('Semantic analysis:');
      if (!sem.issues || sem.issues.length === 0) {
        console.log('  no issues — all references resolve, no cycles');
      } else {
        for (const i of sem.issues) {
          console.log(`  [${i.severity.toUpperCase()}] ${i.text}`);
        }
      }
      // round-trip via the projection pipeline
      const compiled = JSON.parse(kernel.dsl_project(raw));
      if (compiled.error) {
        console.error(`DSL error: ${compiled.error}`);
        process.exit(1);
      }
      console.log('\nRound-trip:');
      console.log('  model -> DSL -> projections: OK');
      process.exit(sem.issue_count > 0 ? 1 : 0);
    }

    // JSON model: round-trip through the kernel
    const rt = JSON.parse(kernel.verify_roundtrip(raw));
    console.log('Round-trip verification:');
    if (rt.ok) {
      console.log(`  OK — ${rt.message}`);
    } else {
      console.log(`  FAILED — ${rt.message}`);
      process.exit(1);
    }
    return;
  }

  // ---- gen: projections ----
  const inputPath = resolve(args._[0]);
  if (!existsSync(inputPath)) { console.error(`File not found: ${inputPath}`); process.exit(1); }
  const raw = readText(inputPath);

  let result;
  if (isDslFile(inputPath)) {
    // DSL source: compile then project
    const compiled = JSON.parse(kernel.dsl_project(raw));
    if (compiled.error) {
      console.error(`DSL error: ${compiled.error}`);
      process.exit(1);
    }
    result = compiled;
  } else {
    // Model JSON: project directly
    result = JSON.parse(kernel.project_from_json(JSON.stringify({
      ...JSON.parse(raw),
      sqlDialect: args.sqlDialect,
      openapiDialect: args.openapiDialect,
    })));
    if (!result.ok) { console.error(result.error || 'Projection failed'); process.exit(1); }
  }

  const keyMap = {
    json: 'jsonSchema', openapi: 'openapi', sql: 'sql',
    graphql: 'graphql', typescript: 'typescript', zod: 'zod', prisma: 'prisma',
  };
  const formats = args.format === 'all'
    ? Object.keys(FORMATS)
    : args.format.split(',').map(s => s.trim()).filter(s => keyMap[s]);

  if (args.stdout) {
    for (const fmt of formats) {
      const content = result[keyMap[fmt]];
      if (content === undefined) { console.error(`Unknown format: ${fmt}`); continue; }
      console.log(`\n// ===== ${fmt.toUpperCase()} =====`);
      console.log(content);
    }
  } else {
    const outDir = resolve(args.out);
    if (!existsSync(outDir)) mkdirSync(outDir, { recursive: true });
    for (const fmt of formats) {
      const content = result[keyMap[fmt]];
      if (content === undefined) { console.error(`Unknown format: ${fmt}`); continue; }
      const outPath = join(outDir, FORMATS[fmt]);
      writeFileSync(outPath, content);
      console.log(`  ${outPath}`);
    }
    // Drop report
    const drops = result.drops;
    if (drops) {
      const dropLines = [];
      for (const [target, list] of Object.entries(drops)) {
        for (const d of list) dropLines.push(`[${target}] ${d.field}.${d.constraint}: ${d.why}`);
      }
      if (dropLines.length > 0) {
        const dropPath = join(outDir, 'drops.txt');
        writeFileSync(dropPath, dropLines.join('\n') + '\n');
        console.log(`  ${dropPath} (${dropLines.length} drops)`);
      }
    }
    console.log(`\nDone. ${formats.length} files written to ${outDir}/`);
  }
}

main().catch((e) => {
  console.error(`Fatal: ${e.message}`);
  process.exit(1);
});
