import type { FieldInput, TypeSpec, CheckInput } from '../lib/types';

const TYPE_OPTIONS = [
  { value: 'Bool', label: 'Bool' },
  { value: 'Int', label: 'Int (32bit)' },
  { value: 'Big', label: 'Big (64bit)' },
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

  // Derive display type string from kind (handles compound types)
  const kindStr = typeof field.kind === 'string' ? field.kind : '__compound';

  return (
    <div className="border border-slate-200 rounded-lg p-3 space-y-2 bg-slate-50">
      {/* Row 1: name + type + delete */}
      <div className="flex gap-2">
        <input
          type="text"
          placeholder="field name"
          className="flex-1 px-2 py-1.5 border border-slate-300 rounded text-sm"
          value={field.name}
          onChange={(e) => onChange({ ...field, name: e.target.value })}
        />
        <select
          className="px-2 py-1.5 border border-slate-300 rounded text-sm bg-white"
          value={kindStr}
          onChange={(e) => {
            const v = e.target.value;
            if (v === '__list') {
              onChange({ ...field, kind: { list: 'Text' } as TypeSpec });
            } else if (v === '__dict') {
              onChange({ ...field, kind: { dict: 'Text' } as TypeSpec });
            } else if (v !== '__compound') {
              onChange({ ...field, kind: v as TypeSpec });
            }
          }}
        >
          {TYPE_OPTIONS.map((t) => (
            <option key={t.value} value={t.value}>
              {t.label}
            </option>
          ))}
          <option value="__compound">(compound)</option>
          <option value="__list">List(Text)</option>
          <option value="__dict">Dict(Text)</option>
        </select>
        <button
          className="px-2 py-1 text-xs text-red-500 hover:bg-red-50 rounded"
          onClick={onRemove}
        >
          Del
        </button>
      </div>

      {/* Row 2: required + nullable */}
      <div className="flex items-center gap-4">
        <label className="flex items-center gap-1.5 text-xs text-slate-600">
          <input
            type="checkbox"
            checked={field.required}
            onChange={(e) => onChange({ ...field, required: e.target.checked })}
          />
          required
        </label>
        <label className="flex items-center gap-1.5 text-xs text-slate-600">
          <input
            type="checkbox"
            checked={field.nullable}
            onChange={(e) => onChange({ ...field, nullable: e.target.checked })}
          />
          nullable
        </label>
      </div>

      {/* Row 3: doc */}
      <input
        type="text"
        placeholder="doc"
        className="w-full px-2 py-1.5 border border-slate-300 rounded text-xs"
        value={field.doc}
        onChange={(e) => onChange({ ...field, doc: e.target.value })}
      />

      {/* Constraints (collapsible) */}
      <details className="text-xs">
        <summary className="cursor-pointer text-slate-500 select-none">
          Checks
        </summary>
        <div className="mt-2 space-y-2 pl-2">
          <div className="grid grid-cols-2 gap-2">
            {(['least', 'most', 'over', 'under'] as const).map((k) => (
              <label key={k} className="flex items-center gap-1">
                <span className="text-slate-500 w-12">{k}</span>
                <input
                  type="number"
                  className="w-full px-1 py-0.5 border rounded"
                  value={field.check[k] ?? ''}
                  onChange={(e) =>
                    updateCheck({ [k]: e.target.value ? Number(e.target.value) : null })
                  }
                />
              </label>
            ))}
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
                onChange={(e) => updateCheck({ format: e.target.value || null })}
              >
                <option value="">none</option>
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
                  updateCheck({ shortest: e.target.value ? Number(e.target.value) : null })
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
                  updateCheck({ longest: e.target.value ? Number(e.target.value) : null })
                }
              />
            </label>
          </div>
          <label className="flex items-center gap-1">
            <span className="text-slate-500 w-12">pattern</span>
            <input
              type="text"
              className="flex-1 px-1 py-0.5 border rounded"
              placeholder="regex"
              value={field.check.pattern ?? ''}
              onChange={(e) => updateCheck({ pattern: e.target.value || null })}
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
