import type { DropReason } from '../lib/types';

interface Props {
  drops: DropReason[];
}

const CONSTRAINT_COLORS: Record<string, string> = {
  unique: 'bg-purple-100 text-purple-700 dark:bg-purple-900/40 dark:text-purple-300',
  pattern: 'bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-300',
  format: 'bg-cyan-100 text-cyan-700 dark:bg-cyan-900/40 dark:text-cyan-300',
  step: 'bg-orange-100 text-orange-700 dark:bg-orange-900/40 dark:text-orange-300',
  distinct: 'bg-pink-100 text-pink-700 dark:bg-pink-900/40 dark:text-pink-300',
  least: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300',
  most: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300',
  over: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300',
  under: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300',
  shortest: 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300',
  longest: 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300',
  options: 'bg-violet-100 text-violet-700 dark:bg-violet-900/40 dark:text-violet-300',
  '(field)': 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300',
};

export function DropReport({ drops }: Props) {
  if (drops.length === 0) {
    return (
      <div className="px-4 py-2 text-xs text-emerald-600 dark:text-emerald-400 border-t border-slate-100 dark:border-slate-700 bg-emerald-50 dark:bg-emerald-900/20">
        All constraints carried by this target
      </div>
    );
  }

  return (
    <div className="border-t border-slate-100 dark:border-slate-700 bg-amber-50 dark:bg-amber-900/20 px-4 py-2">
      <div className="text-xs font-medium text-amber-700 dark:text-amber-300 mb-1.5">
        Dropped constraints ({drops.length})
      </div>
      <div className="flex flex-wrap gap-1.5">
        {drops.map((d, i) => (
          <span
            key={i}
            className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-medium ${CONSTRAINT_COLORS[d.constraint] || 'bg-slate-100 text-slate-600'} cursor-help`}
            title={d.why}
          >
            <span className="font-mono">{d.field}.{d.constraint}</span>
          </span>
        ))}
      </div>
    </div>
  );
}
