import type { FieldInput, TypeSpec, CheckInput } from '../lib/types';

const TYPE_OPTIONS: { value: TypeSpec; label: string }[] = [
  { value: 'Bool', label: 'Bool' },
  { value: 'Int', label: 'Int (32位)' },
  { value: 'Big', label: 'Big (64位)' },
  { value: 'Real', label: 'Real' },
  { value: 'Text', label: 'Text' },
  { value: 'Bytes', label: 'Bytes' },
  { value: 'Stamp', label: 'Stamp' },
  { value: 'Any', label: 'Any' },
];

const FORMAT_OPTIONS = ['email', 'uri', 'date-time', 'uuid', 'ipv4'];

interface Props {
  field: FieldInput;
  onChange: (field: FieldInput) => void;
  onRemove: () => void;
}

export function FieldEditor({ field, onChange, onRemove }: Props) {
  const updateCheck = (patch: Partial<CheckInput>) => {
    onChange({ ...field, check: { ...field.check, ...patch } });
  };

  return (
    <div className="border border-slate-200 rounded-lg p-3 space-y-2 bg-slate-50">
      {/* 行1: 名称 + 类型 + 删除 */}
      <div className="flex gap-2">
        <input
          type="text"
          placeholder="字段名"
          className="flex-1 px-2 py-1.5 border border-slate-300 rounded text-sm"
          value={field.name}
          onChange={(e) => onChange({ ...field, name: e.target.value })}
        />
        <select
          className="px-2 py-1.5 border border-slate-300 rounded text-sm bg-white"
          value={typeof field.kind === 'string' ? field.kind : ''}
          onChange={(e) =>
            onChange({ ...field, kind: e.target.value as TypeSpec })
          }
        >
          {TYPE_OPTIONS.map((t) => (
            <option key={String(t.value)} value={String(t.value)}>
              {t.label}
            </option>
          ))}
          <option value="__list">List(Text)</option>
          <option value="__dict">Dict(Text)</option>
          <option value="__ref">Ref(…)</option>
        </select>
        <button
          className="px-2 py-1 text-xs text-red-500 hover:bg-red-50 rounded"
          onClick={onRemove}
        >
          删除
        </button>
      </div>

      {/* 行2: required + nullable */}
      <div className="flex items-center gap-4">
        <label className="flex items-center gap-1.5 text-xs text-slate-600">
          <input
            type="checkbox"
            checked={field.required}
            onChange={(e) =>
              onChange({ ...field, required: e.target.checked })
            }
          />
          required
        </label>
        <label className="flex items-center gap-1.5 text-xs text-slate-600">
          <input
            type="checkbox"
            checked={field.nullable}
            onChange={(e) =>
              onChange({ ...field, nullable: e.target.checked })
            }
          />
          nullable
        </label>
      </div>

      {/* 行3: doc */}
      <input
        type="text"
        placeholder="文档说明"
        className="w-full px-2 py-1.5 border border-slate-300 rounded text-xs"
        value={field.doc}
        onChange={(e) => onChange({ ...field, doc: e.target.value })}
      />

      {/* 约束面板（可折叠） */}
      <details className="text-xs">
        <summary className="cursor-pointer text-slate-500 select-none">
          约束（
          {Object.values(field.check).filter(
            (v) => v !== undefined && v !== null && v !== false && (!Array.isArray(v) || v.length > 0),
          ).length || 0}
          ）
        </summary>
        <div className="mt-2 space-y-2 pl-2">
          <div className="grid grid-cols-2 gap-2">
            <label className="flex items-center gap-1">
              <span className="text-slate-500 w-12">least</span>
              <input
                type="number"
                className="w-full px-1 py-0.5 border rounded"
                value={field.check.least ?? ''}
                onChange={(e) =>
                  updateCheck({ least: e.target.value ? Number(e.target.value) : null })
                }
              />
            </label>
            <label className="flex items-center gap-1">
              <span className="text-slate-500 w-12">most</span>
              <input
                type="number"
                className="w-full px-1 py-0.5 border rounded"
                value={field.check.most ?? ''}
                onChange={(e) =>
                  updateCheck({ most: e.target.value ? Number(e.target.value) : null })
                }
              />
            </label>
            <label className="flex items-center gap-1">
              <span className="text-slate-500 w-12">over</span>
              <input
                type="number"
                className="w-full px-1 py-0.5 border rounded"
                value={field.check.over ?? ''}
                onChange={(e) =>
                  updateCheck({ over: e.target.value ? Number(e.target.value) : null })
                }
              />
            </label>
            <label className="flex items-center gap-1">
              <span className="text-slate-500 w-12">under</span>
              <input
                type="number"
                className="w-full px-1 py-0.5 border rounded"
                value={field.check.under ?? ''}
                onChange={(e) =>
                  updateCheck({ under: e.target.value ? Number(e.target.value) : null })
                }
              />
            </label>
            <label className="flex items-center gap-1">
              <span className="text-slate-500 w-12">step</span>
              <input
                type="number"
                step="any"
                className="w-full px-1 py-0.5 border rounded"
                value={field.check.step ?? ''}
                onChange={(e) =>
                  updateCheck({ step: e.target.value ? Number(e.target.value) : null })
                }
              />
            </label>
            <label className="flex items-center gap-1">
              <span className="text-slate-500 w-12">format</span>
              <select
                className="w-full px-1 py-0.5 border rounded bg-white"
                value={field.check.format ?? ''}
                onChange={(e) =>
                  updateCheck({ format: e.target.value || null })
                }
              >
                <option value="">无</option>
                {FORMAT_OPTIONS.map((f) => (
                  <option key={f} value={f}>
                    {f}
                  </option>
                ))}
              </select>
            </label>
            <label className="flex items-center gap-1">
              <span className="text-slate-500 w-12">shortest</span>
              <input
                type="number"
                className="w-full px-1 py-0.5 border rounded"
                value={field.check.shortest ?? ''}
                onChange={(e) =>
                  updateCheck({
                    shortest: e.target.value ? Number(e.target.value) : null,
                  })
                }
              />
            </label>
            <label className="flex items-center gap-1">
              <span className="text-slate-500 w-12">longest</span>
              <input
                type="number"
                className="w-full px-1 py-0.5 border rounded"
                value={field.check.longest ?? ''}
                onChange={(e) =>
                  updateCheck({
                    longest: e.target.value ? Number(e.target.value) : null,
                  })
                }
              />
            </label>
          </div>
          <label className="flex items-center gap-1">
            <span className="text-slate-500 w-12">pattern</span>
            <input
              type="text"
              className="flex-1 px-1 py-0.5 border rounded"
              placeholder="正则表达式"
              value={field.check.pattern ?? ''}
              onChange={(e) =>
                updateCheck({ pattern: e.target.value || null })
              }
            />
          </label>
          <div className="flex gap-4">
            <label className="flex items-center gap-1">
              <input
                type="checkbox"
                checked={field.check.distinct ?? false}
                onChange={(e) => updateCheck({ distinct: e.target.checked })}
              />
              distinct
            </label>
            <label className="flex items-center gap-1">
              <input
                type="checkbox"
                checked={field.check.unique ?? false}
                onChange={(e) => updateCheck({ unique: e.target.checked })}
              />
              unique
            </label>
          </div>
        </div>
      </details>
    </div>
  );
}
