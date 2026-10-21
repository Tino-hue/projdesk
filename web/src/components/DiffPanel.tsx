import { useState } from 'react';
import { diffModels, ModelDiff } from '../lib/diff';
import type { ModelInput } from '../lib/types';

interface Props {
  model: ModelInput;
  snapshots: { label: string; data: string }[];
}

export function DiffPanel({ model, snapshots }: Props) {
  const [selectedIndex, setSelectedIndex] = useState(-1);
  const [diff, setDiff] = useState<ModelDiff | null>(null);

  const runDiff = (index: number) => {
    setSelectedIndex(index);
    if (index < 0 || index >= snapshots.length) { setDiff(null); return; }
    try {
      const oldModel = JSON.parse(snapshots[index].data);
      setDiff(diffModels(oldModel, model));
    } catch { setDiff(null); }
  };

  if (snapshots.length === 0) return null;

  const typeColor = { added: 'text-emerald-600 bg-emerald-50', removed: 'text-red-600 bg-red-50', modified: 'text-amber-600 bg-amber-50', unchanged: 'text-slate-400' };

  return (
    <details className="mx-4 mb-4 text-xs">
      <summary className="cursor-pointer text-slate-500 dark:text-slate-400 select-none font-medium">
        Model Diff ({snapshots.length} snapshots)
      </summary>
      <div className="mt-2 space-y-2">
        <select
          className="px-2 py-1 border border-slate-300 dark:border-slate-600 rounded text-xs bg-white dark:bg-slate-800 dark:text-slate-200 w-full"
          value={selectedIndex}
          onChange={(e) => runDiff(Number(e.target.value))}
        >
          <option value={-1}>Select a snapshot to compare...</option>
          {snapshots.map((s, i) => <option key={i} value={i}>{s.label}</option>)}
        </select>

        {diff && (
          <div className="border border-slate-200 dark:border-slate-700 rounded-lg p-3 space-y-1">
            {diff.nameChange && (
              <div className="text-xs text-amber-600">Name: {diff.nameChange.from} → {diff.nameChange.to}</div>
            )}
            {diff.fields.filter((f) => f.type !== 'unchanged').map((f, i) => (
              <div key={i} className="flex items-start gap-2">
                <span className={`px-1.5 py-0.5 rounded text-[10px] font-medium ${typeColor[f.type]}`}>{f.type}</span>
                <div>
                  <span className="font-mono font-medium">{f.name}</span>
                  {f.changes.map((c, j) => <div key={j} className="text-slate-500 dark:text-slate-400 ml-2">{c}</div>)}
                </div>
              </div>
            ))}
            {diff.fields.every((f) => f.type === 'unchanged') && (
              <div className="text-slate-400 text-xs">No changes</div>
            )}
          </div>
        )}
      </div>
    </details>
  );
}
