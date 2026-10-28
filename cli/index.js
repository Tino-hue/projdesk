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
  projdesk init <ModelName> [--out <dir>] [--as-json]

Options:
  -o, --out <dir>        Output directory (default: ./projdesk-out)
  --format <fmts>        Comma-separated: ${Object.keys(FORMATS).join(', ')} (default: all)
  --sql-dialect <d>      Postgres | Sqlite | Mysql (default: Postgres)
  --openapi-dialect <d>  OpenApi30 | OpenApi31 | Swagger20 (default: OpenApi30)
  --stdout               Print to stdout instead of writing files
  --json                 Emit machine-readable JSON (for CI)
  -h, --help             Show this help

Examples:
  projdesk gen model.json
  projdesk gen model.dsl --format json,sql --out ./schemas
  projdesk gen model.json --sql-dialect Sqlite --stdout
  projdesk check model.json
  projdesk migrate old.json new.json
  projdesk verify model.dsl
  projdesk init Order --out ./models
`);
}

function parseArgs(argv) {
  const args = { _: [], out: 'projdesk-out', format: 'all', sqlDialect: 'Postgres', openapiDialect: 'OpenApi30', stdout: false, json: false, scaffold: 'dsl' };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '-h' || a === '--help') { usage(); process.exit(0); }
    else if (a === '-o' || a === '--out') args.out = argv[++i];
    else if (a === '--format') args.format = argv[++i];
    else if (a === '--sql-dialect') args.sqlDialect = argv[++i];
    else if (a === '--openapi-dialect') args.openapiDialect = argv[++i];
    else if (a === '--stdout') args.stdout = true;
    else if (a === '--json') args.json = true;
    else if (a === '--as-json') args.scaffold = 'json';
    else if (a === '--dsl') args.scaffold = 'dsl';
    else if (['gen', 'check', 'migrate', 'verify', 'init'].includes(a)) args.cmd = a;
    else args._.push(a);
  }
  return args;
}

async function loadKernel() {
  const wasmPath = join(__dirname, 'projdesk.wasm');
  if (!existsSync(wasmPath)) {
    throw new Error(
      `Kernel not found at ${wasmPath}\n` +
      'Build it with the MoonBit toolchain, then copy the artifact:\n' +
      '  cd moonbit && moon build --target wasm-gc --release\n' +
      '  copy _build/wasm-gc/release/build/main/main.wasm ../cli/projdesk.wasm\n' +
      'Or run setup.ps1 / build.ps1 from the repository root.'
    );
  }
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
    if (args.json) {
      console.log(JSON.stringify({
        issues: diags,
        conflict_count: result.conflict_count,
        redundant_count: result.redundant_count,
        ok: result.conflict_count === 0,
      }, null, 2));
    } else if (diags.length === 0) {
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

  // ---- init: scaffold a new model ----
  if (args.cmd === 'init') {
    const name = args._[0];
    if (!name) {
      console.error('Usage: projdesk init <ModelName> [--out <dir>] [--as-json]');
      process.exit(1);
    }
    const outDir = resolve(args.out);
    if (!existsSync(outDir)) mkdirSync(outDir, { recursive: true });

    if (args.scaffold === 'json') {
      const model = {
        name,
        doc: `${name} model`,
        fields: [
          { name: 'id', kind: 'Big', required: true, nullable: false, doc: 'primary key', default: null, check: { unique: true } },
          { name: 'name', kind: 'Text', required: true, nullable: false, doc: 'display name', default: null, check: { shortest: 1, longest: 64 } },
          { name: 'createdAt', kind: 'Stamp', required: true, nullable: false, doc: 'creation time', default: null, check: {} },
        ],
        known: [],
      };
      const file = join(outDir, `${name}.json`);
      writeFileSync(file, JSON.stringify(model, null, 2) + '\n');
      console.log(`  ${file}`);
    } else {
      const dsl = `// ${name} model
model ${name} {
  // primary key
  id: Big @unique
  // display name
  name: Text [shortest=1, longest=64]
  // creation time
  createdAt: Stamp
}
`;
      const file = join(outDir, `${name}.dsl`);
      writeFileSync(file, dsl);
      console.log(`  ${file}`);
    }
    console.log(`\nCreated ${name}. Next: projdesk gen ${name}.${args.scaffold === 'json' ? 'json' : 'dsl'} --out ./generated`);
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
        if (args.json) {
          console.log(JSON.stringify({ ok: false, parse_error: sem.parse_error }, null, 2));
        } else {
          console.error(`Parse error: ${sem.parse_error}`);
        }
        process.exit(1);
      }
      // round-trip via the projection pipeline
      const compiled = JSON.parse(kernel.dsl_project(raw));
      if (compiled.error) {
        if (args.json) {
          console.log(JSON.stringify({ ok: false, parse_error: compiled.error }, null, 2));
        } else {
          console.error(`DSL error: ${compiled.error}`);
        }
        process.exit(1);
      }
      if (args.json) {
        console.log(JSON.stringify({
          ok: (sem.issue_count || 0) === 0,
          issues: sem.issues || [],
          issue_count: sem.issue_count || 0,
          roundtrip: 'ok',
        }, null, 2));
      } else {
        console.log('Semantic analysis:');
        if (!sem.issues || sem.issues.length === 0) {
          console.log('  no issues — all references resolve, no cycles');
        } else {
          for (const i of sem.issues) {
            console.log(`  [${i.severity.toUpperCase()}] ${i.text}`);
          }
        }
        console.log('\nRound-trip:');
        console.log('  model -> DSL -> projections: OK');
      }
      process.exit((sem.issue_count || 0) > 0 ? 1 : 0);
    }

    // JSON model: round-trip through the kernel
    const rt = JSON.parse(kernel.verify_roundtrip(raw));
    if (args.json) {
      console.log(JSON.stringify({ ok: rt.ok, message: rt.message }, null, 2));
    } else {
      console.log('Round-trip verification:');
      if (rt.ok) {
        console.log(`  OK — ${rt.message}`);
      } else {
        console.log(`  FAILED — ${rt.message}`);
      }
    }
    if (!rt.ok) process.exit(1);
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
        for (const d of list) dropLines.push(`[${target}] ${d.why}`);
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
