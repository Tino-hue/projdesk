import { useState, useRef, DragEvent } from 'react';
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
  fields: FieldInput[];
  onChange: (fields: FieldInput[]) => void;
}

export function FieldList({ fields, onChange }: Props) {
  const [filter, setFilter] = useState('');
  const dragIndex = useRef<number | null>(null);
  const [dragOverIndex, setDragOverIndex] = useState<number | null>(null);

  const filtered = fields
    .map((f, i) => ({ field: f, index: i }))
    .filter(({ field }) => {
      if (!filter) return true;
      const q = filter.toLowerCase();
      return field.name.toLowerCase().includes(q) || field.doc.toLowerCase().includes(q) || field.kind.toString().toLowerCase().includes(q);
    });

  const updateField = (index: number, patch: Partial<FieldInput>) => {
    onChange(fields.map((f, i) => (i === index ? { ...f, ...patch } : f)));
  };

  const removeField = (index: number) => {
    onChange(fields.filter((_, i) => i !== index));
  };

  const addField = () => {
    onChange([...fields, { name: '', kind: 'Text', required: true, nullable: false, doc: '', default: null, check: {} }]);
  };

  const duplicateField = (index: number) => {
    const clone = { ...fields[index], name: fields[index].name + '_copy' };
    const next = [...fields];
    next.splice(index + 1, 0, clone);
    onChange(next);
  };

  // Drag handlers
  const handleDragStart = (e: DragEvent, index: number) => {
    dragIndex.current = index;
    e.dataTransfer.effectAllowed = 'move';
  };

  const handleDragOver = (e: DragEvent, index: number) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    setDragOverIndex(index);
  };

  const handleDrop = (e: DragEvent, targetIndex: number) => {
    e.preventDefault();
    const from = dragIndex.current;
    if (from === null || from === targetIndex) return;
    const next = [...fields];
    const [moved] = next.splice(from, 1);
    next.splice(targetIndex, 0, moved);
    onChange(next);
    dragIndex.current = null;
    setDragOverIndex(null);
  };

  const handleDragEnd = () => {
    dragIndex.current = null;
    setDragOverIndex(null);
  };

  return (
    <div>
      {/* Search bar */}
      <div className="flex items-center gap-2 mb-2">
        <input
          type="text"
          className="flex-1 px-2 py-1 border border-slate-300 dark:border-slate-600 rounded text-xs bg-white dark:bg-slate-800"
          placeholder="Search fields..."
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
        />
        <button
          className="px-2 py-1 text-xs bg-blue-500 text-white rounded hover:bg-blue-600"
          onClick={addField}
        >
          + Add
        </button>
      </div>
      <div className="text-[10px] text-slate-400 mb-2">
        {filtered.length} of {fields.length} fields{filter && ` (filtered by "${filter}")`}
        {fields.length > 1 && ' | Drag to reorder'}
      </div>

      {/* Field list with drag support */}
      <div className="space-y-2">
        {filtered.map(({ field, index }) => (
          <div
            key={`${index}-${field.name}`}
            draggable
            onDragStart={(e) => handleDragStart(e, index)}
            onDragOver={(e) => handleDragOver(e, index)}
            onDrop={(e) => handleDrop(e, index)}
            onDragEnd={handleDragEnd}
            className={`border rounded-lg p-2 space-y-1.5 bg-slate-50 dark:bg-slate-800 dark:border-slate-700 cursor-grab active:cursor-grabbing ${
              dragOverIndex === index ? 'border-blue-400 shadow-md' : 'border-slate-200'
            } ${dragIndex.current === index ? 'opacity-50' : ''}`}
          >
            {/* Row: name + type + actions */}
            <div className="flex gap-1.5">
              <span className="text-slate-400 text-xs select-none px-0.5 self-center">⠿</span>
              <input
                type="text"
                placeholder="name"
                className="flex-1 px-1.5 py-1 border border-slate-300 dark:border-slate-600 rounded text-xs bg-white dark:bg-slate-700 dark:text-slate-200"
                value={field.name}
                onChange={(e) => updateField(index, { name: e.target.value })}
              />
              <select
                className="px-1 py-1 border border-slate-300 dark:border-slate-600 rounded text-xs bg-white dark:bg-slate-700 dark:text-slate-200"
                value={typeof field.kind === 'string' ? field.kind : '__compound'}
                onChange={(e) => {
                  const v = e.target.value;
                  if (v === '__list') updateField(index, { kind: { list: 'Text' } as TypeSpec });
                  else if (v === '__dict') updateField(index, { kind: { dict: 'Text' } as TypeSpec });
                  else if (v !== '__compound') updateField(index, { kind: v as TypeSpec });
                }}
              >
                {TYPE_OPTIONS.map((t) => <option key={t.value} value={t.value}>{t.label}</option>)}
                <option value="__compound">(compound)</option>
                <option value="__list">List(Text)</option>
                <option value="__dict">Dict(Text)</option>
              </select>
              <button className="text-xs text-slate-400 hover:text-blue-500 px-1" onClick={() => duplicateField(index)} title="Duplicate">⧉</button>
              <button className="text-xs text-slate-400 hover:text-red-500 px-1" onClick={() => removeField(index)} title="Remove">✕</button>
            </div>

            {/* Row: required + nullable */}
            <div className="flex items-center gap-3">
              <label className="flex items-center gap-1 text-[10px] text-slate-600 dark:text-slate-400">
                <input type="checkbox" checked={field.required} onChange={(e) => updateField(index, { required: e.target.checked })} />
                required
              </label>
              <label className="flex items-center gap-1 text-[10px] text-slate-600 dark:text-slate-400">
                <input type="checkbox" checked={field.nullable} onChange={(e) => updateField(index, { nullable: e.target.checked })} />
                nullable
              </label>
            </div>

            {/* Row: doc */}
            <input
              type="text"
              placeholder="doc"
              className="w-full px-1.5 py-1 border border-slate-300 dark:border-slate-600 rounded text-[10px] bg-white dark:bg-slate-700 dark:text-slate-200"
              value={field.doc}
              onChange={(e) => updateField(index, { doc: e.target.value })}
            />

            {/* Checks (collapsible) */}
            <details className="text-[10px]">
              <summary className="cursor-pointer text-slate-500 dark:text-slate-400 select-none">
                Checks
              </summary>
              <div className="mt-1.5 space-y-1.5 pl-1">
                <div className="grid grid-cols-2 gap-1.5">
                  {(['least', 'most', 'over', 'under'] as const).map((k) => (
                    <label key={k} className="flex items-center gap-1">
                      <span className="text-slate-500 dark:text-slate-400 w-10">{k}</span>
                      <input type="number" className="w-full px-1 py-0.5 border border-slate-300 dark:border-slate-600 rounded bg-white dark:bg-slate-700 dark:text-slate-200" value={field.check[k] ?? ''} onChange={(e) => { const check: CheckInput = { ...field.check, [k]: e.target.value ? Number(e.target.value) : null }; updateField(index, { check }); }} />
                    </label>
                  ))}
                  <label className="flex items-center gap-1">
                    <span className="text-slate-500 dark:text-slate-400 w-10">step</span>
                    <input type="number" step="any" className="w-full px-1 py-0.5 border border-slate-300 dark:border-slate-600 rounded bg-white dark:bg-slate-700 dark:text-slate-200" value={field.check.step ?? ''} onChange={(e) => updateField(index, { check: { ...field.check, step: e.target.value ? Number(e.target.value) : null } })} />
                  </label>
                  <label className="flex items-center gap-1">
                    <span className="text-slate-500 dark:text-slate-400 w-10">format</span>
                    <select className="w-full px-1 py-0.5 border border-slate-300 dark:border-slate-600 rounded bg-white dark:bg-slate-700 dark:text-slate-200" value={field.check.format ?? ''} onChange={(e) => updateField(index, { check: { ...field.check, format: e.target.value || null } })}>
                      <option value="">none</option>
                      {FORMAT_OPTIONS.map((f) => <option key={f} value={f}>{f}</option>)}
                    </select>
                  </label>
                  <label className="flex items-center gap-1">
                    <span className="text-slate-500 dark:text-slate-400 w-10">min</span>
                    <input type="number" className="w-full px-1 py-0.5 border border-slate-300 dark:border-slate-600 rounded bg-white dark:bg-slate-700 dark:text-slate-200" value={field.check.shortest ?? ''} onChange={(e) => updateField(index, { check: { ...field.check, shortest: e.target.value ? Number(e.target.value) : null } })} />
                  </label>
                  <label className="flex items-center gap-1">
                    <span className="text-slate-500 dark:text-slate-400 w-10">max</span>
                    <input type="number" className="w-full px-1 py-0.5 border border-slate-300 dark:border-slate-600 rounded bg-white dark:bg-slate-700 dark:text-slate-200" value={field.check.longest ?? ''} onChange={(e) => updateField(index, { check: { ...field.check, longest: e.target.value ? Number(e.target.value) : null } })} />
                  </label>
                </div>
                <label className="flex items-center gap-1">
                  <span className="text-slate-500 dark:text-slate-400 w-10">regex</span>
                  <input type="text" className="flex-1 px-1 py-0.5 border border-slate-300 dark:border-slate-600 rounded bg-white dark:bg-slate-700 dark:text-slate-200" placeholder="pattern" value={field.check.pattern ?? ''} onChange={(e) => updateField(index, { check: { ...field.check, pattern: e.target.value || null } })} />
                </label>
                <div className="flex gap-3">
                  <label className="flex items-center gap-1">
                    <input type="checkbox" checked={field.check.distinct ?? false} onChange={(e) => updateField(index, { check: { ...field.check, distinct: e.target.checked } })} />
                    distinct
                  </label>
                  <label className="flex items-center gap-1">
                    <input type="checkbox" checked={field.check.unique ?? false} onChange={(e) => updateField(index, { check: { ...field.check, unique: e.target.checked } })} />
                    unique
                  </label>
                </div>
              </div>
            </details>
          </div>
        ))}
      </div>
    </div>
  );
}
