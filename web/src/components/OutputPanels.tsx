import type { KernelOutput, DropReason } from '../lib/types';
import { DropReport } from './DropReport';

interface Props {
  output: KernelOutput | null;
}

interface PanelDef {
  key: keyof KernelOutput;
  dropKey: keyof KernelOutput['drops'];
  title: string;
  lang: string;
}

const PANELS: PanelDef[] = [
  { key: 'jsonSchema', dropKey: 'jsonSchema', title: 'JSON Schema 2020-12', lang: 'json' },
  { key: 'openapi', dropKey: 'openapi', title: 'OpenAPI 3.0 Schema Object', lang: 'json' },
  { key: 'sql', dropKey: 'sql', title: 'SQL DDL (Postgres)', lang: 'sql' },
  { key: 'graphql', dropKey: 'graphql', title: 'GraphQL SDL', lang: 'graphql' },
];

function copyToClipboard(text: string) {
  navigator.clipboard.writeText(text).catch(() => {
    // fallback
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

export function OutputPanels({ output }: Props) {
  if (!output) {
    return (
      <div className="flex items-center justify-center h-full text-slate-400 text-sm">
        在左侧编辑模型，四栏产物将同步刷新
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 xl:grid-cols-2 gap-4 p-4">
      {PANELS.map((panel) => {
        const text = (output[panel.key] as string) || '';
        const drops = (output.drops[panel.dropKey] as DropReason[]) || [];
        return (
          <div
            key={panel.key}
            className="border border-slate-200 rounded-xl overflow-hidden bg-white shadow-sm"
          >
            {/* 面板头 */}
            <div className="flex items-center justify-between px-4 py-2.5 border-b border-slate-100 bg-slate-50">
              <div className="flex items-center gap-2">
                <h2 className="text-sm font-semibold text-slate-700">
                  {panel.title}
                </h2>
                {drops.length > 0 && (
                  <span className="drop-badge bg-amber-100 text-amber-700">
                    {drops.length} 项丢弃
                  </span>
                )}
              </div>
              <div className="flex gap-1">
                <button
                  className="px-2 py-1 text-xs text-slate-500 hover:bg-slate-200 rounded"
                  onClick={() => copyToClipboard(text)}
                >
                  复制
                </button>
                <button
                  className="px-2 py-1 text-xs text-slate-500 hover:bg-slate-200 rounded"
                  onClick={() =>
                    downloadFile(
                      `${output.ok ? 'projdesk' : 'export'}.${panel.lang === 'sql' ? 'sql' : panel.lang === 'graphql' ? 'graphql' : 'json'}`,
                      text,
                    )
                  }
                >
                  导出
                </button>
              </div>
            </div>

            {/* 代码 */}
            <div className="code-block max-h-[360px]">{text}</div>

            {/* 丢弃报告 */}
            <DropReport drops={drops} />
          </div>
        );
      })}
    </div>
  );
}
