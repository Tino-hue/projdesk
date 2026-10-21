#!/usr/bin/env node
// ProjDesk CLI - generate 7 projections from a model JSON
// All projection algorithms live in the MoonBit WASM kernel

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import { resolve, dirname, basename, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// ---------- Helpers ----------

function usage() {
  console.log(`
ProjDesk CLI - one model description, seven projections

Usage:
  projdesk gen <model.json> [options]

Options:
  -o, --out <dir>     Output directory (default: ./projdesk-out)
  --format <fmts>     Comma-separated formats (default: all)
                      json, openapi, sql, graphql, typescript, zod, prisma
  --sql-dialect <d>   Postgres | Sqlite | Mysql (default: Postgres)
  --openapi-dialect <d>  OpenApi30 | OpenApi31 | Swagger20 (default: OpenApi30)
  --stdout            Print to stdout instead of writing files
  -h, --help          Show this help

Examples:
  projdesk gen model.json
  projdesk gen model.json --format json,sql --out ./schemas
  projdesk gen model.json --sql-dialect Sqlite --stdout
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
    else if (a === 'gen') continue;
    else args._.push(a);
  }
  return args;
}

// ---------- WASM loading ----------

async function loadKernel() {
  const wasmPath = join(__dirname, 'projdesk.wasm');
  const bytes = readFileSync(wasmPath);
  const { instance } = await WebAssembly.instantiate(bytes, {}, {
    builtins: ['js-string'],
    importedStringConstants: '_',
  });
  return instance.exports;
}

// ---------- Main ----------

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args._.length === 0) {
    usage();
    process.exit(1);
  }

  const inputPath = resolve(args._[0]);
  if (!existsSync(inputPath)) {
    console.error(`Error: File not found: ${inputPath}`);
    process.exit(1);
  }

  const inputJson = readFileSync(inputPath, 'utf-8');
  let model;
  try {
    model = JSON.parse(inputJson);
  } catch (e) {
    console.error(`Error: Invalid JSON in ${inputPath}: ${e.message}`);
    process.exit(1);
  }

  const kernel = await loadKernel();
  const resultJson = kernel.project_from_json(JSON.stringify({
    ...model,
    sqlDialect: args.sqlDialect,
    openapiDialect: args.openapiDialect,
  }));

  const result = JSON.parse(resultJson);
  if (!result.ok) {
    console.error(`Error: ${result.error}`);
    process.exit(1);
  }

  const formats = args.format === 'all'
    ? ['json', 'openapi', 'sql', 'graphql', 'typescript', 'zod', 'prisma']
    : args.format.split(',').map(s => s.trim());

  const outputs = {
    json: { content: result.jsonSchema, ext: 'json', name: 'schema.json' },
    openapi: { content: result.openapi, ext: 'json', name: 'openapi.json' },
    sql: { content: result.sql, ext: 'sql', name: 'schema.sql' },
    graphql: { content: result.graphql, ext: 'graphql', name: 'schema.graphql' },
    typescript: { content: result.typescript, ext: 'ts', name: 'types.ts' },
    zod: { content: result.zod, ext: 'ts', name: 'schema.zod.ts' },
    prisma: { content: result.prisma, ext: 'prisma', name: 'schema.prisma' },
  };

  if (args.stdout) {
    for (const fmt of formats) {
      const o = outputs[fmt];
      if (!o) { console.error(`Unknown format: ${fmt}`); continue; }
      console.log(`\n// ===== ${fmt.toUpperCase()} =====`);
      console.log(o.content);
    }
  } else {
    const outDir = resolve(args.out);
    if (!existsSync(outDir)) mkdirSync(outDir, { recursive: true });
    for (const fmt of formats) {
      const o = outputs[fmt];
      if (!o) { console.error(`Unknown format: ${fmt}`); continue; }
      const outPath = join(outDir, o.name);
      writeFileSync(outPath, o.content);
      console.log(`  ${outPath}`);
    }
    // Write drop report
    const drops = result.drops;
    const dropLines = [];
    for (const [target, list] of Object.entries(drops)) {
      for (const d of list) {
        dropLines.push(`[${target}] ${d.field}.${d.constraint}: ${d.why}`);
      }
    }
    if (dropLines.length > 0) {
      const dropPath = join(outDir, 'drops.txt');
      writeFileSync(dropPath, dropLines.join('\n') + '\n');
      console.log(`  ${dropPath} (${dropLines.length} drops)`);
    }
    console.log(`\nDone. ${formats.length} files written to ${outDir}/`);
  }
}

main().catch((e) => {
  console.error(`Fatal: ${e.message}`);
  process.exit(1);
});
