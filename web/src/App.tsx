import { useState, useEffect, useCallback, useRef } from 'react';
import type { KernelInput, KernelOutput, ModelInput, FieldInput, PresetModel } from './lib/types';
import { project, getPresets } from './lib/wasm';
import { importModel, downloadModel } from './lib/modelio';
import { HistoryManager, encodeToHash, decodeFromHash } from './lib/history';
import { saveState, loadState, clearState } from './lib/persistence';
import { FieldEditor } from './components/FieldEditor';
import { OutputPanels } from './components/OutputPanels';

function makeEmptyField(): FieldInput {
  return { name: '', kind: 'Text', required: true, nullable: false, doc: '', default: null, check: {} };
}
function makeEmptyModel(name: string): ModelInput {
  return { name, doc: '', fields: [makeEmptyField()] };
}

type OpenApiDialect = 'OpenApi30' | 'OpenApi31' | 'Swagger20';
type SqlDialect = 'Postgres' | 'Sqlite' | 'Mysql';

interface ModelEntry { id: string; model: ModelInput; }

let nextId = 1;
function genId(): string { return `m${nextId++}`; }

export default function App() {
  const [models, setModels] = useState<ModelEntry[]>([]);
  const [activeId, setActiveId] = useState('');
  const [output, setOutput] = useState<KernelOutput | null>(null);
  const [presets, setPresets] = useState<PresetModel[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [openapiDialect, setOpenapiDialect] = useState<OpenApiDialect>('OpenApi30');
  const [sqlDialect, setSqlDialect] = useState<SqlDialect>('Postgres');
  const [shareMsg, setShareMsg] = useState('');
  const debounceRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const historyRef = useRef(new HistoryManager());
  const [canUndo, setCanUndo] = useState(false);
  const [canRedo, setCanRedo] = useState(false);

  const active = models.find((m) => m.id === activeId);
  const activeModel = active?.model;
  const known = models.filter((m) => m.id !== activeId).map((m) => m.model);

  // Undo/Redo
  const saveSnapshot = useCallback(() => {
    historyRef.current.push({ models: JSON.stringify(models), activeId });
    setCanUndo(historyRef.current.canUndo());
    setCanRedo(historyRef.current.canRedo());
  }, [models, activeId]);

  const undo = useCallback(() => {
    const entry = historyRef.current.undo();
    if (entry) {
      setModels(JSON.parse(entry.models));
      setActiveId(entry.activeId);
      setCanUndo(historyRef.current.canUndo());
      setCanRedo(historyRef.current.canRedo());
    }
  }, []);

  const redo = useCallback(() => {
    const entry = historyRef.current.redo();
    if (entry) {
      setModels(JSON.parse(entry.models));
      setActiveId(entry.activeId);
      setCanUndo(historyRef.current.canUndo());
      setCanRedo(historyRef.current.canRedo());
    }
  }, []);

  // Share URL
  const shareUrl = useCallback(() => {
    const hash = encodeToHash({ models, activeId, openapiDialect, sqlDialect });
    const url = `${location.origin}${location.pathname}#${hash}`;
    navigator.clipboard.writeText(url).then(() => {
      setShareMsg('Link copied!');
      setTimeout(() => setShareMsg(''), 2000);
    }).catch(() => {
      location.hash = hash;
      setShareMsg('URL updated!');
      setTimeout(() => setShareMsg(''), 2000);
    });
  }, [models, activeId, openapiDialect, sqlDialect]);

  // Load from URL hash or localStorage on mount
  useEffect(() => {
    const hash = location.hash.slice(1);
    if (hash) {
      const data = decodeFromHash(hash);
      if (data && Array.isArray(data.models) && data.models.length > 0) {
        const entries = data.models.map((m: unknown) => ({ id: genId(), model: m as ModelInput }));
        setModels(entries);
        setActiveId(data.activeId || entries[0].id);
        return;
      }
    }
    const saved = loadState();
    if (saved) {
      const entries = saved.models.map((m) => ({ id: genId(), model: m.model as ModelInput }));
      setModels(entries);
      setActiveId(saved.activeId || entries[0].id);
      if (saved.openapiDialect) setOpenapiDialect(saved.openapiDialect as OpenApiDialect);
      if (saved.sqlDialect) setSqlDialect(saved.sqlDialect as SqlDialect);
    }
  }, []);

  // Keyboard shortcuts
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.ctrlKey || e.metaKey) {
        if (e.key === 'z' && !e.shiftKey) { e.preventDefault(); undo(); }
        if (e.key === 'z' && e.shiftKey) { e.preventDefault(); redo(); }
        if (e.key === 'y') { e.preventDefault(); redo(); }
        if (e.key === 's') { e.preventDefault(); if (activeModel) downloadModel(activeModel); }
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [undo, redo, activeModel]);

  // Auto-snapshot
  useEffect(() => {
    const t = setTimeout(() => { if (models.length > 0) saveSnapshot(); }, 500);
    return () => clearTimeout(t);
  }, [models, activeId, saveSnapshot]);

  // Auto-save to localStorage
  useEffect(() => {
    const t = setTimeout(() => {
      if (models.length > 0) {
        saveState({ models, activeId, openapiDialect, sqlDialect });
      }
    }, 300);
    return () => clearTimeout(t);
  }, [models, activeId, openapiDialect, sqlDialect]);

  // Load presets
  useEffect(() => {
    getPresets()
      .then((p) => {
        setPresets(p);
        const user = p.find((m) => m.name === 'User');
        const entries: ModelEntry[] = [];
        if (user) entries.push({ id: genId(), model: { name: user.name, doc: user.doc, fields: user.fields } });
        for (const m of p.filter((x) => x.name !== 'User')) {
          entries.push({ id: genId(), model: { name: m.name, doc: m.doc, fields: m.fields } });
        }
        setModels(entries);
        if (entries.length > 0) setActiveId(entries[0].id);
      })
      .catch((e) => setError(String(e)))
      .finally(() => setLoading(false));
  }, []);

  // Projection
  const runProjection = useCallback(async (m: ModelInput | undefined, k: ModelInput[]) => {
    if (!m || m.fields.length === 0) { setOutput(null); return; }
    try {
      const result = await project({ ...m, known: k, openapiDialect, sqlDialect } as KernelInput);
      setOutput(result);
    } catch (e) { setError(String(e)); }
  }, [openapiDialect, sqlDialect]);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => runProjection(activeModel, known), 200);
    return () => { if (debounceRef.current) clearTimeout(debounceRef.current); };
  }, [activeModel, known, runProjection]);

  // Model mutations
  const updateModel = (patch: Partial<ModelInput>) => {
    setModels((prev) => prev.map((m) => (m.id === activeId ? { ...m, model: { ...m.model, ...patch } } : m)));
  };
  const updateField = (index: number, field: FieldInput) => {
    if (!activeModel) return;
    updateModel({ fields: activeModel.fields.map((f, i) => (i === index ? field : f)) });
  };
  const addField = () => { if (activeModel) updateModel({ fields: [...activeModel.fields, makeEmptyField()] }); };
  const removeField = (index: number) => { if (activeModel) updateModel({ fields: activeModel.fields.filter((_, i) => i !== index) }); };

  const addModel = () => {
    const entry = { id: genId(), model: makeEmptyModel(`Model${models.length + 1}`) };
    setModels((prev) => [...prev, entry]);
    setActiveId(entry.id);
  };
  const removeModel = (id: string) => {
    setModels((prev) => {
      const next = prev.filter((m) => m.id !== id);
      if (id === activeId && next.length > 0) setActiveId(next[0].id);
      return next;
    });
  };
  const duplicateModel = (id: string) => {
    const src = models.find((m) => m.id === id);
    if (!src) return;
    const entry = { id: genId(), model: { ...src.model, name: src.model.name + '_copy', fields: [...src.model.fields] } };
    setModels((prev) => [...prev, entry]);
    setActiveId(entry.id);
  };
  const loadPreset = (name: string) => {
    const p = presets.find((m) => m.name === name);
    if (!p) return;
    const entry = { id: genId(), model: { name: p.name, doc: p.doc, fields: p.fields } };
    setModels((prev) => [...prev, entry]);
    setActiveId(entry.id);
  };

  if (loading) return <div className="flex items-center justify-center h-screen"><div className="text-lg text-slate-500">Loading MoonBit kernel...</div></div>;

  return (
    <div className="h-screen flex flex-col">
      <header className="bg-white border-b border-slate-200 px-4 py-2 flex items-center justify-between shrink-0">
        <h1 className="text-lg font-bold text-slate-800">ProjDesk <span className="text-xs font-normal text-slate-400">One Definition, Four Projections</span></h1>
        <div className="flex items-center gap-1.5">
          <select className="px-2 py-1 border border-slate-300 rounded text-xs bg-white" value={openapiDialect} onChange={(e) => setOpenapiDialect(e.target.value as OpenApiDialect)}>
            <option value="OpenApi30">OpenAPI 3.0</option><option value="OpenApi31">OpenAPI 3.1</option><option value="Swagger20">Swagger 2.0</option>
          </select>
          <select className="px-2 py-1 border border-slate-300 rounded text-xs bg-white" value={sqlDialect} onChange={(e) => setSqlDialect(e.target.value as SqlDialect)}>
            <option value="Postgres">Postgres</option><option value="Sqlite">SQLite</option><option value="Mysql">MySQL</option>
          </select>
          <select className="px-2 py-1 border border-slate-300 rounded text-xs bg-white" value="" onChange={(e) => e.target.value && loadPreset(e.target.value)}>
            <option value="">+ Preset...</option>
            {presets.map((p) => <option key={p.name} value={p.name}>{p.name}</option>)}
          </select>
          <label className="px-2 py-1 text-xs bg-slate-100 hover:bg-slate-200 rounded cursor-pointer">Import<input type="file" accept=".json" className="hidden" onChange={(e) => {
            const file = e.target.files?.[0]; if (!file) return;
            file.text().then((text) => {
              const m = importModel(text);
              if (m) { const entry = { id: genId(), model: m }; setModels((p) => [...p, entry]); setActiveId(entry.id); }
              else setError('Invalid model JSON');
            }); e.target.value = '';
          }} /></label>
          {activeModel && <button className="px-2 py-1 text-xs bg-slate-100 hover:bg-slate-200 rounded" onClick={() => downloadModel(activeModel)}>Export</button>}
          <button className="px-2 py-1 text-xs bg-slate-100 hover:bg-slate-200 rounded disabled:opacity-40" disabled={!canUndo} onClick={undo} title="Ctrl+Z">Undo</button>
          <button className="px-2 py-1 text-xs bg-slate-100 hover:bg-slate-200 rounded disabled:opacity-40" disabled={!canRedo} onClick={redo} title="Ctrl+Shift+Z">Redo</button>
          <button className="px-2 py-1 text-xs bg-emerald-500 text-white rounded hover:bg-emerald-600" onClick={shareUrl}>Share</button>
          {shareMsg && <span className="text-xs text-emerald-600">{shareMsg}</span>}
          <button className="px-2 py-1 text-xs text-slate-400 hover:text-red-500 rounded" onClick={() => { clearState(); location.reload(); }} title="Clear saved data">Reset</button>
        </div>
      </header>

      {error && <div className="bg-red-50 border-b border-red-200 px-4 py-1 text-xs text-red-700">{error}</div>}

      <div className="flex-1 flex overflow-hidden">
        {/* Sidebar: model list */}
        <div className="w-[180px] border-r border-slate-200 bg-slate-50 flex flex-col shrink-0">
          <div className="p-2 border-b border-slate-200">
            <button className="w-full px-2 py-1.5 text-xs bg-blue-500 text-white rounded hover:bg-blue-600" onClick={addModel}>+ New Model</button>
          </div>
          <div className="flex-1 overflow-y-auto">
            {models.map((m) => (
              <div key={m.id} className={`px-3 py-2 cursor-pointer border-b border-slate-100 flex items-center justify-between group ${m.id === activeId ? 'bg-blue-50 border-l-2 border-l-blue-500' : 'hover:bg-slate-100'}`} onClick={() => setActiveId(m.id)}>
                <div><div className="text-xs font-medium text-slate-700">{m.model.name || '(unnamed)'}</div><div className="text-[10px] text-slate-400">{m.model.fields.length} fields</div></div>
                <div className="flex gap-1 opacity-0 group-hover:opacity-100">
                  <button className="text-[10px] text-slate-400 hover:text-blue-500" onClick={(e) => { e.stopPropagation(); duplicateModel(m.id); }}>Dup</button>
                  {models.length > 1 && <button className="text-[10px] text-slate-400 hover:text-red-500" onClick={(e) => { e.stopPropagation(); removeModel(m.id); }}>X</button>}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Center: field editor */}
        <div className="w-[320px] border-r border-slate-200 bg-white overflow-y-auto shrink-0">
          {activeModel ? (
            <div className="p-3 space-y-3">
              <input type="text" className="w-full px-2 py-1.5 border border-slate-300 rounded text-sm font-medium" value={activeModel.name} onChange={(e) => updateModel({ name: e.target.value })} placeholder="Model name" />
              <input type="text" className="w-full px-2 py-1 border border-slate-300 rounded text-xs" value={activeModel.doc} onChange={(e) => updateModel({ doc: e.target.value })} placeholder="Doc" />
              <div className="flex items-center justify-between">
                <span className="text-xs text-slate-500">Fields ({activeModel.fields.length})</span>
                <button className="px-2 py-1 text-xs bg-blue-500 text-white rounded hover:bg-blue-600" onClick={addField}>+ Add</button>
              </div>
              <div className="space-y-2">
                {activeModel.fields.map((field, i) => (
                  <FieldEditor key={`${i}-${field.name}`} field={field} onChange={(f) => updateField(i, f)} onRemove={() => removeField(i)} />
                ))}
              </div>
            </div>
          ) : <div className="p-4 text-sm text-slate-400">No model selected</div>}
        </div>

        {/* Right: output panels */}
        <div className="flex-1 overflow-auto">
          <OutputPanels output={output} openapiDialect={openapiDialect} sqlDialect={sqlDialect} model={activeModel || makeEmptyModel('')} known={known} />
        </div>
      </div>
    </div>
  );
}

