import type { DropReason } from '../lib/types';

interface Props {
  drops: DropReason[];
}

export function DropReport({ drops }: Props) {
  if (drops.length === 0) {
    return (
      <div className="px-4 py-2 text-xs text-emerald-600 border-t border-slate-100 bg-emerald-50">
        ✓ 本目标可完整承载所有约束
      </div>
    );
  }

  return (
    <div className="border-t border-slate-100 bg-amber-50 px-4 py-2">
      <div className="text-xs font-medium text-amber-700 mb-1.5">
        已丢弃约束（诚实投影）
      </div>
      <div className="space-y-1">
        {drops.map((d, i) => (
          <div
            key={i}
            className="flex items-start gap-2 text-xs text-amber-800"
          >
            <span className="drop-badge bg-amber-200 text-amber-800 shrink-0">
              {d.field}.{d.constraint}
            </span>
            <span className="text-amber-700 leading-relaxed">{d.why}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
