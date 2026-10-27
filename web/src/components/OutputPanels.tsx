import { useRef, useEffect } from 'react';
import type { KernelOutput, DropReason, ModelInput } from '../lib/types';
import { DropReport } from './DropReport';
import { CoverageMatrix } from './CoverageMatrix';
import { HighlightedCode, diffLines } from './CodeHighlight';
import { ModelDiagram } from './ModelDiagram';

interface Props {
  output: KernelOutput | null;
  openapiDialect: string;
  sqlDialect: string;
  model: ModelInput;
  known: ModelInput[];
}

function copyToClipboard(text: string) {
  navigator.clipboard.writeText(text).catch(() => {
    const ta = document.createElement('textarea');
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    document.execCommand('copy');
    document.body.removeChild(ta);
  });
}

function downloadFile(filename: string, content: string) {
  const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

function copyAll(output: KernelOutput) {
  const text = [
    '=== JSON Schema 2020-12 ===', output.jsonSchema,
    '=== OpenAPI ===', output.openapi,
    '=== SQL DDL ===', output.sql,
    '=== GraphQL SDL ===', output.graphql,
    '=== TypeScript ===', output.typescript || '',
    '=== Zod ===', output.zod || '',
    '=== Prisma ===', output.prisma || '',
  ].join('\n\n');
  copyToClipboard(text);
}

function exportAll(output: KernelOutput) {
  downloadFile('schema.json', output.jsonSchema);
  downloadFile('openapi.json', output.openapi);
  downloadFile('schema.sql', output.sql);
  downloadFile('schema.graphql', output.graphql);
  downloadFile('types.ts', output.typescript || '');
  downloadFile('schema.zod.ts', output.zod || '');
  downloadFile('schema.prisma', output.prisma || '');
}

const DIALECT_LABELS: Record<string, string> = {
  OpenApi30: 'OpenAPI 3.0',
  OpenApi31: 'OpenAPI 3.1',
  Swagger20: 'Swagger 2.0',
  Postgres: 'Postgres',
  Sqlite: 'SQLite',
  Mysql: 'MySQL',
};

export function OutputPanels({ output, openapiDialect, sqlDialect, model, known }: Props) {
  const prevOutputRef = useRef<KernelOutput | null>(null);
  useEffect(() => {
    if (output) prevOutputRef.current = output;
  }, [output]);

  if (!output) {
    return <div className="flex items-center justify-center h-full text-slate-400 text-sm">Edit model on the left; four panels refresh live.</div>;
  }

  // Compute changed lines vs previous output
  const prev = prevOutputRef.current;
  const changed = {
    jsonSchema: prev ? diffLines(prev.jsonSchema, output.jsonSchema) : new Set<number>(),
    openapi: prev ? diffLines(prev.openapi, output.openapi) : new Set<number>(),
    sql: prev ? diffLines(prev.sql, output.sql) : new Set<number>(),
    graphql: prev ? diffLines(prev.graphql, output.graphql) : new Set<number>(),
  };
  // If first render, no changes
  const isFirst = !prev;
  const changeSets = {
    jsonSchema: isFirst ? new Set<number>() : changed.jsonSchema,
    openapi: isFirst ? new Set<number>() : changed.openapi,
    sql: isFirst ? new Set<number>() : changed.sql,
    graphql: isFirst ? new Set<number>() : changed.graphql,
  };

  const panels = [
    { key: 'jsonSchema' as const, dropKey: 'jsonSchema' as const, title: 'JSON Schema 2020-12', ext: 'json', lang: 'json' },
    { key: 'openapi' as const, dropKey: 'openapi' as const, title: `${DIALECT_LABELS[openapiDialect] || 'OpenAPI'} Schema Object`, ext: 'json', lang: 'json' },
    { key: 'sql' as const, dropKey: 'sql' as const, title: `SQL DDL (${DIALECT_LABELS[sqlDialect] || 'Postgres'})`, ext: 'sql', lang: 'sql' },
    { key: 'graphql' as const, dropKey: 'graphql' as const, title: 'GraphQL SDL', ext: 'graphql', lang: 'graphql' },
  ];

  return (
    <div>
      {/* Toolbar */}
      <div className="flex flex-wrap items-center justify-between px-2 sm:px-4 pt-4 pb-2 gap-2">
        <span className="text-xs text-slate-400">
          Four projections live
          <span className="ml-2 text-amber-500 text-xs">
            {Object.values(changeSets).some((s) => s.size > 0) ? '鈼? lines highlighted = just changed' : ''}
          </span>
        </span>
        <div className="flex gap-2">
          <button className="px-3 py-1.5 text-xs bg-blue-500 text-white rounded hover:bg-blue-600" onClick={() => copyAll(output)}>Copy All</button>
          <button className="px-3 py-1.5 text-xs bg-slate-200 hover:bg-slate-300 rounded" onClick={() => exportAll(output)}>Export All</button>
        </div>
      </div>

      {/* Model diagram */}
      <ModelDiagram model={model} known={known} />

      {/* Coverage matrix */}
      <CoverageMatrix drops={output.drops} />

      {/* Four panels */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-3 px-2 sm:px-4 pb-4">
        {panels.map((panel) => {
          const text = (output[panel.key] as string) || '';
          const drops = (output.drops[panel.dropKey] as DropReason[]) || [];
          const changes = changeSets[panel.key];
          return (
            <div key={panel.key} className="border border-slate-200 rounded-xl overflow-hidden bg-white shadow-sm">
              <div className="flex items-center justify-between px-4 py-2.5 border-b border-slate-100 bg-slate-50">
                <div className="flex items-center gap-2">
                  <h2 className="text-sm font-semibold text-slate-700">{panel.title}</h2>
                  {drops.length > 0 && <span className="drop-badge bg-amber-100 text-amber-700">{drops.length} drops</span>}
                  {changes.size > 0 && <span className="drop-badge bg-blue-100 text-blue-700">{changes.size} changed</span>}
                </div>
                <div className="flex gap-1">
                  <button className="px-2 py-1 text-xs text-slate-500 hover:bg-slate-200 rounded" onClick={() => copyToClipboard(text)}>Copy</button>
                  <button className="px-2 py-1 text-xs text-slate-500 hover:bg-slate-200 rounded" onClick={() => downloadFile(`projdesk.${panel.ext}`, text)}>Export</button>
                </div>
              </div>
              <HighlightedCode code={text} lang={panel.lang} changedLines={changes} />
              <DropReport drops={drops} />
            </div>
          );
        })}
      </div>
    </div>
  );
}


