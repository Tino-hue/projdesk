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
  projdesk check-schema <schema.json>
  projdesk contrast <model.dsl>
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
  projdesk check-schema openapi.json
  projdesk contrast model.dsl
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
    else if (['gen', 'check', 'check-schema', 'contrast', 'migrate', 'verify', 'init'].includes(a)) args.cmd = a;
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

/**
 * The model JSON the migration engine compares. A DSL source is compiled
 * first; the kernel is the only thing that can parse it.
 */
async function modelJson(kernel, path) {
  const resolved = resolve(path);
  if (!existsSync(resolved)) {
    console.error(`File not found: ${resolved}`);
    process.exit(1);
  }
  const raw = readText(resolved);
  if (!isDslFile(resolved)) return raw;
  const compiled = JSON.parse(kernel.dsl_to_model(raw));
  if (compiled.error) {
    console.error(`Could not compile ${resolved}: ${compiled.error}`);
    process.exit(1);
  }
  return JSON.stringify(compiled);
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

    let result;
    if (isDslFile(inputPath)) {
      // a DSL source is compiled to a model first, then analysed
      const model = JSON.parse(kernel.dsl_to_model(raw));
      if (model.error) { console.error(`Parse error: ${model.error}`); process.exit(1); }
      result = JSON.parse(kernel.solve_constraints(JSON.stringify(model)));
    } else {
      result = JSON.parse(kernel.solve_constraints(raw));
    }
    const diags = (result.diagnoses || []).filter((d) => d.severity !== 'ok');
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
        console.log(`  ${d.text}`);
      }
    }
    if (result.conflict_count > 0) process.exit(1);
    return;
  }

  // ---- check-schema: does anything satisfy this JSON Schema at all? ----
  //
  // The ecosystem's validators answer "does this value satisfy the schema?".
  // This answers the other question: can anything satisfy it? A schema with
  // `minimum: 10` and `maximum: 5` passes every conformance suite and
  // rejects every value that reaches it.
  if (args.cmd === 'check-schema') {
    const inputPath = resolve(args._[0]);
    if (!existsSync(inputPath)) { console.error(`File not found: ${inputPath}`); process.exit(1); }
    const raw = readText(inputPath);
    const result = JSON.parse(kernel.check_schema_satisfiability(raw));
    const findings = result.findings || [];
    if (args.json) {
      console.log(JSON.stringify({
        ok: result.ok,
        findings,
        finding_count: result.finding_count,
      }, null, 2));
    } else if (findings.length === 0) {
      console.log('No contradictions found. The schema admits at least one value.');
    } else {
      console.log(`${findings.length} contradiction(s) found:`);
      for (const f of findings) {
        console.log(`  [${f.kind}] ${f.path || '(root)'} — ${f.message}`);
      }
    }
    if (findings.length > 0) process.exit(1);
    return;
  }

  // ---- contrast: what the solver sees that the projection does not ----
  if (args.cmd === 'contrast') {
    const inputPath = resolve(args._[0]);
    if (!existsSync(inputPath)) { console.error(`File not found: ${inputPath}`); process.exit(1); }
    const raw = readText(inputPath);

    const model = JSON.parse(kernel.dsl_to_model(raw));
    if (model.error) { console.error(`Could not compile ${inputPath}: ${model.error}`); process.exit(1); }
    const projected = JSON.parse(kernel.dsl_project(raw));
    const solved = JSON.parse(kernel.solve_constraints(JSON.stringify(model)));

    const schema = JSON.parse(projected.jsonSchema);
    const properties = schema.properties || {};
    const diagnoses = solved.diagnoses || [];

    if (args.json) {
      console.log(JSON.stringify({ model: model.name, diagnoses, conflict_count: solved.conflict_count }, null, 2));
      process.exit(solved.conflict_count > 0 ? 1 : 0);
    }

    console.log(`Model: ${model.name}`);
    console.log('');
    for (const field of model.fields) {
      const keywords = properties[field.name] || {};
      const carried = Object.keys(keywords)
        .filter((k) => k !== 'type')
        .map((k) => `${k}: ${keywords[k]}`);
      const findings = diagnoses.filter((d) => d.text.includes(`${field.name}:`));
      const kind = typeof field.kind === 'string' ? field.kind : JSON.stringify(field.kind);
      console.log(`  ${field.name} (${kind})`);
      console.log(`    projection (moonmodel)  ${carried.join('  ') || '(nothing)'}`);
      if (findings.length === 0) {
        console.log('    solver (this project)   no findings');
      } else {
        for (const d of findings) console.log(`    solver (this project)   ${d.text}`);
      }
    }
    console.log('');
    if (diagnoses.length === 0) {
      console.log('The solver found nothing the projection would have hidden.');
    } else {
      console.log('The projection carries these through without saying anything about them.');
    }
    process.exit(solved.conflict_count > 0 ? 1 : 0);
  }

  // ---- migrate: SQL migration ----
  if (args.cmd === 'migrate') {
    if (args._.length < 2) { console.error('Need two model files'); process.exit(1); }
    const oldJson = await modelJson(kernel, args._[0]);
    const newJson = await modelJson(kernel, args._[1]);
    const result = JSON.parse(kernel.generate_migration(oldJson, newJson));
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
      // source round-trip: the DSL is printed back and parsed again
      const rt = JSON.parse(kernel.verify_roundtrip_dsl(raw));
      if (args.json) {
        console.log(JSON.stringify({
          ok: (sem.issue_count || 0) === 0 && rt.ok,
          issues: sem.issues || [],
          issue_count: sem.issue_count || 0,
          roundtrip: rt.ok ? 'ok' : rt.message,
          // The kind and the stage say why it failed and where, without the
          // caller having to read the message.
          roundtrip_reason: rt.ok ? null : (rt.reason || null),
          roundtrip_stage: rt.ok ? null : (rt.stage || null),
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
        if (rt.ok) {
          console.log(`  OK — ${rt.message}`);
        } else {
          console.log(`  FAILED — ${rt.message}`);
        }
      }
      process.exit((sem.issue_count || 0) > 0 || !rt.ok ? 1 : 0);
    }

    // JSON model: round-trip through the kernel
    const rt = JSON.parse(kernel.verify_roundtrip(raw));
    if (args.json) {
      console.log(JSON.stringify({
        ok: rt.ok,
        message: rt.message,
        reason: rt.ok ? null : (rt.reason || null),
        stage: rt.ok ? null : (rt.stage || null),
      }, null, 2));
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
