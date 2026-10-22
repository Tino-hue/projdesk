import { useState, useRef, DragEvent } from 'react';
import type { FieldInput, TypeSpec, CheckInput } from '../lib/types';

const TYPE_OPTIONS = [
  { value: 'Bool', label: 'Bool' },
  { value: 'Int', label: 'Int' },
  { value: 'Big', label: 'Big' },
  { value: 'Real', label: 'Real' },
  { value: 'Text', label: 'Text' },
  { value: 'Bytes', label: 'Bytes' },
  { value: 'Stamp', label: 'Stamp' },
  { value: 'Any', label: 'Any' },
  { value: '__list', label: 'List[Text]' },
  { value: '__dict', label: 'Dict[str]' },
  { value: '__compound', label: '...' },
];

const FORMAT_OPTIONS = ['email', 'uri', 'date-time', 'uuid', 'ipv4'];

function typeLabel(kind: TypeSpec): string {
  if (typeof kind === 'string') return kind;
  if ('list' in kind) return `List[${typeLabel(kind.list)}]`;
  if ('dict' in kind) return `Dict[${typeLabel(kind.dict)}]`;
  if ('ref' in kind) return `Ref(${kind.ref})`;
  if ('nest' in kind) return 'Nested';
  return '...';
}

function typeSelectValue(kind: TypeSpec): string {
  if (typeof kind === 'string') return kind;
  if ('list' in kind && kind.list === 'Text') return '__list';
  if ('dict' in kind && kind.dict === 'Text') return '__dict';
  return '__compound';
}

interface Props {
  fields: FieldInput[];
  onChange: (fields: FieldInput[]) => void;
}

export function FieldList({ fields, onChange }: Props) {
  const [filter, setFilter] = useState('');
  const [expandedIdx, setExpandedIdx] = useState<number | null>(null);
  const dragIndex = useRef<number | null>(null);
  const [dragOverIdx, setDragOverIdx] = useState<number | null>(null);

  const filtered = fields
    .map((f, i) => ({ field: f, index: i }))
    .filter(({ field }) => {
      if (!filter) return true;
      const q = filter.toLowerCase();
      return (
        field.name.toLowerCase().includes(q) ||
        field.doc.toLowerCase().includes(q) ||
        typeLabel(field.kind).toLowerCase().includes(q)
      );
    });

  const updateField = (index: number, patch: Partial<FieldInput>) => {
    onChange(fields.map((f, i) => (i === index ? { ...f, ...patch } : f)));
  };

  const removeField = (index: number) => {
    onChange(fields.filter((_, i) => i !== index));
  };

  const addField = () => {
    onChange([
      ...fields,
      { name: '', kind: 'Text', required: true, nullable: false, doc: '', default: null, check: {} },
    ]);
  };

  const duplicateField = (index: number) => {
    const clone = { ...fields[index], name: fields[index].name + '_copy' };
    const next = [...fields];
    next.splice(index + 1, 0, clone);
    onChange(next);
  };

  // Drag handlers
  const onDragStart = (e: DragEvent, idx: number) => {
    dragIndex.current = idx;
    e.dataTransfer.effectAllowed = 'move';
  };
  const onDragOver = (e: DragEvent, idx: number) => {
    e.preventDefault();
    setDragOverIdx(idx);
  };
  const onDrop = (e: DragEvent, target: number) => {
    e.preventDefault();
    const from = dragIndex.current;
    if (from === null || from === target) return;
    const next = [...fields];
    const [moved] = next.splice(from, 1);
    next.splice(target, 0, moved);
    onChange(next);
    dragIndex.current = null;
    setDragOverIdx(null);
  };
  const onDragEnd = () => {
    dragIndex.current = null;
    setDragOverIdx(null);
  };

  return (
    <div>
      {/* Toolbar */}
      <div className="flex items-center gap-2 mb-2">
        <input
          type="text"
          className="flex-1 px-2 py-1 border border-slate-200 dark:border-slate-700 rounded-md text-xs bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-300 focus:outline-none focus:ring-1 focus:ring-blue-500/40"
          placeholder="Search fields..."
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
        />
        <button
          className="px-2.5 py-1 text-xs bg-blue-500 text-white rounded-md hover:bg-blue-600 active:scale-[0.97] transition-all"
          onClick={addField}
        >
          + Add
        </button>
      </div>

      {/* Count */}
      <div className="flex items-center justify-between text-[10px] text-slate-400 mb-1.5">
        <span>
          {filter ? `${filtered.length} of ${fields.length}` : `${fields.length} fields`}
          {fields.length > 1 && ' · drag to reorder'}
        </span>
      </div>

      {/* Field cards */}
      <div className="space-y-1">
        {filtered.map(({ field, index }) => {
          const isExpanded = expandedIdx === index;
          return (
            <div
              key={`${index}-${field.name}`}
              draggable
              onDragStart={(e) => onDragStart(e, index)}
              onDragOver={(e) => onDragOver(e, index)}
              onDrop={(e) => onDrop(e, index)}
              onDragEnd={onDragEnd}
              className={`border rounded-lg bg-white dark:bg-slate-800/60 transition-all cursor-grab active:cursor-grabbing ${
                dragOverIdx === index
                  ? 'border-blue-400 shadow-sm'
                  : 'border-slate-200/80 dark:border-slate-700/60'
              } ${dragIndex.current === index ? 'opacity-50' : ''}`}
            >
              {/* Row 1: drag handle + name + type + actions */}
              <div className="flex items-center gap-1.5 px-2 py-1.5">
                <span className="text-slate-300 dark:text-slate-600 text-[10px] select-none cursor-grab">⠿</span>
                <input
                  type="text"
                  placeholder="name"
                  className="flex-1 min-w-0 px-1.5 py-1 text-xs bg-transparent border-0 focus:outline-none focus:ring-1 focus:ring-blue-500/40 rounded text-slate-800 dark:text-slate-200"
                  value={field.name}
                  onChange={(e) => updateField(index, { name: e.target.value })}
                />
                <select
                  className="px-1.5 py-1 text-[11px] border border-slate-200 dark:border-slate-600 rounded bg-white dark:bg-slate-700 text-slate-600 dark:text-slate-300 focus:outline-none focus:ring-1 focus:ring-blue-500/40"
                  value={typeSelectValue(field.kind)}
                  onChange={(e) => {
                    const v = e.target.value;
                    if (v === '__list') updateField(index, { kind: { list: 'Text' } as TypeSpec });
                    else if (v === '__dict') updateField(index, { kind: { dict: 'Text' } as TypeSpec });
                    else if (v !== '__compound') updateField(index, { kind: v as TypeSpec });
                  }}
                >
                  {TYPE_OPTIONS.map((t) => (
                    <option key={t.value} value={t.value}>
                      {t.label}
                    </option>
                  ))}
                </select>
                <button
                  className="p-0.5 text-slate-400 hover:text-blue-500 transition-colors"
                  onClick={() => duplicateField(index)}
                  title="Duplicate"
                >
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg>
                </button>
                <button
                  className="p-0.5 text-slate-400 hover:text-red-500 transition-colors"
                  onClick={() => removeField(index)}
                  title="Remove"
                >
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                </button>
              </div>

              {/* Row 2: flags + doc + expand toggle */}
              <div className="flex items-center gap-2 px-2 pb-1.5">
                <label className="flex items-center gap-1 text-[10px] text-slate-500 dark:text-slate-400 cursor-pointer">
                  <input
                    type="checkbox"
                    className="w-3 h-3 rounded border-slate-300"
                    checked={field.required}
                    onChange={(e) => updateField(index, { required: e.target.checked })}
                  />
                  req
                </label>
                <label className="flex items-center gap-1 text-[10px] text-slate-500 dark:text-slate-400 cursor-pointer">
                  <input
                    type="checkbox"
                    className="w-3 h-3 rounded border-slate-300"
                    checked={field.nullable}
                    onChange={(e) => updateField(index, { nullable: e.target.checked })}
                  />
                  null
                </label>
                <input
                  type="text"
                  placeholder="doc"
                  className="flex-1 min-w-0 px-1.5 py-0.5 text-[10px] bg-slate-50 dark:bg-slate-700/50 border-0 rounded focus:outline-none focus:ring-1 focus:ring-blue-500/40 text-slate-600 dark:text-slate-300"
                  value={field.doc}
                  onChange={(e) => updateField(index, { doc: e.target.value })}
                />
                <button
                  className="text-[10px] text-slate-400 hover:text-blue-500 transition-colors px-0.5"
                  onClick={() => setExpandedIdx(isExpanded ? null : index)}
                  title="Toggle constraints"
                >
                  {isExpanded ? '▲' : '▼'}
                </button>
              </div>

              {/* Expanded: constraints */}
              {isExpanded && (
                <div className="px-2 pb-2 border-t border-slate-100 dark:border-slate-700/50 pt-1.5">
                  <div className="grid grid-cols-3 gap-1 mb-1">
                    {(['least', 'most', 'over', 'under', 'shortest', 'longest'] as const).map((k) => (
                      <label key={k} className="flex items-center gap-0.5">
                        <span className="text-[9px] text-slate-400 w-8 shrink-0">{k}</span>
                        <input
                          type="number"
                          className="w-full min-w-0 px-1 py-0.5 text-[10px] border border-slate-200 dark:border-slate-600 rounded bg-white dark:bg-slate-700 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-1 focus:ring-blue-500/40"
                          value={field.check[k] ?? ''}
                          onChange={(e) => {
                            const check: CheckInput = {
                              ...field.check,
                              [k]: e.target.value ? Number(e.target.value) : null,
                            };
                            updateField(index, { check });
                          }}
                        />
                      </label>
                    ))}
                  </div>
                  <div className="grid grid-cols-2 gap-1 mb-1">
                    <label className="flex items-center gap-0.5">
                      <span className="text-[9px] text-slate-400 w-8 shrink-0">step</span>
                      <input
                        type="number"
                        step="any"
                        className="w-full min-w-0 px-1 py-0.5 text-[10px] border border-slate-200 dark:border-slate-600 rounded bg-white dark:bg-slate-700 text-slate-700 dark:text-slate-200"
                        value={field.check.step ?? ''}
                        onChange={(e) =>
                          updateField(index, {
                            check: { ...field.check, step: e.target.value ? Number(e.target.value) : null },
                          })
                        }
                      />
                    </label>
                    <label className="flex items-center gap-0.5">
                      <span className="text-[9px] text-slate-400 w-8 shrink-0">format</span>
                      <select
                        className="w-full min-w-0 px-1 py-0.5 text-[10px] border border-slate-200 dark:border-slate-600 rounded bg-white dark:bg-slate-700 text-slate-700 dark:text-slate-200"
                        value={field.check.format ?? ''}
                        onChange={(e) =>
                          updateField(index, { check: { ...field.check, format: e.target.value || null } })
                        }
                      >
                        <option value="">none</option>
                        {FORMAT_OPTIONS.map((f) => (
                          <option key={f} value={f}>
                            {f}
                          </option>
                        ))}
                      </select>
                    </label>
                  </div>
                  <label className="flex items-center gap-0.5 mb-1">
                    <span className="text-[9px] text-slate-400 w-8 shrink-0">regex</span>
                    <input
                      type="text"
                      className="flex-1 px-1 py-0.5 text-[10px] border border-slate-200 dark:border-slate-600 rounded bg-white dark:bg-slate-700 text-slate-700 dark:text-slate-200"
                      placeholder="pattern"
                      value={field.check.pattern ?? ''}
                      onChange={(e) =>
                        updateField(index, { check: { ...field.check, pattern: e.target.value || null } })
                      }
                    />
                  </label>
                  <div className="flex gap-3">
                    <label className="flex items-center gap-1 text-[10px] text-slate-500 dark:text-slate-400">
                      <input
                        type="checkbox"
                        className="w-3 h-3"
                        checked={field.check.distinct ?? false}
                        onChange={(e) =>
                          updateField(index, { check: { ...field.check, distinct: e.target.checked } })
                        }
                      />
                      distinct
                    </label>
                    <label className="flex items-center gap-1 text-[10px] text-slate-500 dark:text-slate-400">
                      <input
                        type="checkbox"
                        className="w-3 h-3"
                        checked={field.check.unique ?? false}
                        onChange={(e) =>
                          updateField(index, { check: { ...field.check, unique: e.target.checked } })
                        }
                      />
                      unique
                    </label>
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
