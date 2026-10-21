import type { KernelOutput, DropReason } from '../lib/types';
import { DropReport } from './DropReport';

interface Props {
  output: KernelOutput | null;
  openapiDialect: string;
  sqlDialect: string;
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

const DIALECT_LABELS: Record<string, string> = {
  OpenApi30: 'OpenAPI 3.0',
  OpenApi31: 'OpenAPI 3.1',
  Swagger20: 'Swagger 2.0',
  Postgres: 'Postgres',
  Sqlite: 'SQLite',
  Mysql: 'MySQL',
};

export function OutputPanels({ output, openapiDialect, sqlDialect }: Props) {
  if (!output) {
    return <div className="flex items-center justify-center h-full text-slate-400 text-sm">Edit model on the left; four panels refresh live.</div>;
  }

  const panels = [
    { key: 'jsonSchema' as const, dropKey: 'jsonSchema' as const, title: 'JSON Schema 2020-12', ext: 'json' },
    { key: 'openapi' as const, dropKey: 'openapi' as const, title: `${DIALECT_LABELS[openapiDialect] || 'OpenAPI'} Schema Object`, ext: 'json' },
    { key: 'sql' as const, dropKey: 'sql' as const, title: `SQL DDL (${DIALECT_LABELS[sqlDialect] || 'Postgres'})`, ext: 'sql' },
    { key: 'graphql' as const, dropKey: 'graphql' as const, title: 'GraphQL SDL', ext: 'graphql' },
  ];

  return (
    <div className="grid grid-cols-1 xl:grid-cols-2 gap-4 p-4">
      {panels.map((panel) => {
        const text = (output[panel.key] as string) || '';
        const drops = (output.drops[panel.dropKey] as DropReason[]) || [];
        return (
          <div key={panel.key} className="border border-slate-200 rounded-xl overflow-hidden bg-white shadow-sm">
            <div className="flex items-center justify-between px-4 py-2.5 border-b border-slate-100 bg-slate-50">
              <div className="flex items-center gap-2">
                <h2 className="text-sm font-semibold text-slate-700">{panel.title}</h2>
                {drops.length > 0 && <span className="drop-badge bg-amber-100 text-amber-700">{drops.length} drops</span>}
              </div>
              <div className="flex gap-1">
                <button className="px-2 py-1 text-xs text-slate-500 hover:bg-slate-200 rounded" onClick={() => copyToClipboard(text)}>Copy</button>
                <button className="px-2 py-1 text-xs text-slate-500 hover:bg-slate-200 rounded" onClick={() => downloadFile(`projdesk.${panel.ext}`, text)}>Export</button>
              </div>
            </div>
            <div className="code-block max-h-[360px]">{text}</div>
            <DropReport drops={drops} />
          </div>
        );
      })}
    </div>
  );
}
