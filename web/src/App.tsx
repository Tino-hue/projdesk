import { useState, useEffect, useCallback, useRef } from 'react';
import type { KernelInput, KernelOutput, ModelInput, FieldInput, PresetModel } from './lib/types';
import { project, getPresets } from './lib/wasm';
import { importModel, downloadModel } from './lib/modelio';
import { FieldEditor } from './components/FieldEditor';
import { OutputPanels } from './components/OutputPanels';

function makeEmptyField(): FieldInput {
  return {
    name: '',
    kind: 'Text',
    required: true,
    nullable: false,
    doc: '',
    default: null,
    check: {},
  };
}

type OpenApiDialect = 'OpenApi30' | 'OpenApi31' | 'Swagger20';
type SqlDialect = 'Postgres' | 'Sqlite' | 'Mysql';

export default function App() {
  const [model, setModel] = useState<ModelInput>({ name: 'User', doc: '', fields: [] });
  const [known, setKnown] = useState<ModelInput[]>([]);
  const [output, setOutput] = useState<KernelOutput | null>(null);
  const [presets, setPresets] = useState<PresetModel[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [openapiDialect, setOpenapiDialect] = useState<OpenApiDialect>('OpenApi30');
  const [sqlDialect, setSqlDialect] = useState<SqlDialect>('Postgres');
  const debounceRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  useEffect(() => {
    getPresets()
      .then((p) => {
        setPresets(p);
        const user = p.find((m) => m.name === 'User');
        if (user) {
          setModel({ name: user.name, doc: user.doc, fields: user.fields });
          setKnown(p.filter((m) => m.name !== 'User'));
        }
      })
      .catch((e) => setError(String(e)))
      .finally(() => setLoading(false));
  }, []);

  const runProjection = useCallback(async (m: ModelInput, k: ModelInput[]) => {
    if (m.fields.length === 0) { setOutput(null); return; }
    try {
      const input: KernelInput = { ...m, known: k, openapiDialect, sqlDialect };
      const result = await project(input);
      setOutput(result);
    } catch (e) { setError(String(e)); }
  }, [openapiDialect, sqlDialect]);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => runProjection(model, known), 200);
    return () => { if (debounceRef.current) clearTimeout(debounceRef.current); };
  }, [model, known, runProjection]);

  const updateField = (index: number, field: FieldInput) => {
    setModel((prev) => ({ ...prev, fields: prev.fields.map((f, i) => (i === index ? field : f)) }));
  };
  const addField = () => setModel((prev) => ({ ...prev, fields: [...prev.fields, makeEmptyField()] }));
  const removeField = (index: number) => setModel((prev) => ({ ...prev, fields: prev.fields.filter((_, i) => i !== index) }));
  const loadPreset = (name: string) => {
    const p = presets.find((m) => m.name === name);
    if (p) { setModel({ name: p.name, doc: p.doc, fields: p.fields }); setKnown(presets.filter((m) => m.name !== name)); }
  };

  if (loading) return <div className="flex items-center justify-center h-screen"><div className="text-lg text-slate-500">Loading MoonBit kernel...</div></div>;

  return (
    <div className="min-h-screen flex flex-col">
      <header className="bg-white border-b border-slate-200 px-6 py-3">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-bold text-slate-800">ProjDesk <span className="ml-2 text-sm font-normal text-slate-500">One Definition, Four Projections</span></h1>
            <p className="text-xs text-slate-400">JSON Schema / OpenAPI / SQL DDL / GraphQL SDL</p>
          </div>
          <div className="flex items-center gap-2">
            <select className="px-2 py-1.5 border border-slate-300 rounded text-xs bg-white" value={openapiDialect} onChange={(e) => setOpenapiDialect(e.target.value as OpenApiDialect)}>
              <option value="OpenApi30">OpenAPI 3.0</option>
              <option value="OpenApi31">OpenAPI 3.1</option>
              <option value="Swagger20">Swagger 2.0</option>
            </select>
            <select className="px-2 py-1.5 border border-slate-300 rounded text-xs bg-white" value={sqlDialect} onChange={(e) => setSqlDialect(e.target.value as SqlDialect)}>
              <option value="Postgres">Postgres</option>
              <option value="Sqlite">SQLite</option>
              <option value="Mysql">MySQL</option>
            </select>
            <button className="px-2 py-1.5 text-xs bg-slate-100 hover:bg-slate-200 rounded" onClick={() => downloadModel(model)}>Save JSON</button>
            <label className="px-2 py-1.5 text-xs bg-slate-100 hover:bg-slate-200 rounded cursor-pointer">
              Load JSON
              <input type="file" accept=".json" className="hidden" onChange={(e) => {
                const file = e.target.files?.[0];
                if (!file) return;
                file.text().then((text) => {
                  const m = importModel(text);
                  if (m) { setModel(m); setKnown([]); }
                  else setError('Invalid model JSON');
                });
                e.target.value = '';
              }} />
            </label>
            <select className="px-3 py-1.5 border border-slate-300 rounded-lg text-sm bg-white" value="" onChange={(e) => e.target.value && loadPreset(e.target.value)}>
              <option value="">Load preset...</option>
              {presets.map((p) => <option key={p.name} value={p.name}>{p.name}</option>)}
            </select>
          </div>
        </div>
      </header>

      {error && <div className="bg-red-50 border-b border-red-200 px-6 py-2 text-sm text-red-700">{error}</div>}

      <div className="flex-1 flex flex-col lg:flex-row">
        <div className="lg:w-[420px] border-r border-slate-200 bg-white overflow-y-auto">
          <div className="p-4 space-y-4">
            <div>
              <label className="block text-xs font-medium text-slate-500 mb-1">Model name</label>
              <input type="text" className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm" value={model.name} onChange={(e) => setModel((prev) => ({ ...prev, name: e.target.value }))} />
            </div>
            <div>
              <label className="block text-xs font-medium text-slate-500 mb-1">Doc</label>
              <input type="text" className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm" value={model.doc} onChange={(e) => setModel((prev) => ({ ...prev, doc: e.target.value }))} />
            </div>
            <div>
              <div className="flex items-center justify-between mb-2">
                <label className="text-xs font-medium text-slate-500">Fields ({model.fields.length})</label>
                <button className="px-2 py-1 text-xs bg-blue-500 text-white rounded hover:bg-blue-600" onClick={addField}>+ Add field</button>
              </div>
              <div className="space-y-3">
                {model.fields.map((field, i) => (
                  <FieldEditor key={`${i}-${field.name}`} field={field} onChange={(f) => updateField(i, f)} onRemove={() => removeField(i)} />
                ))}
              </div>
            </div>
          </div>
        </div>
        <div className="flex-1 overflow-auto">
          <OutputPanels output={output} openapiDialect={openapiDialect} sqlDialect={sqlDialect} />
        </div>
      </div>
    </div>
  );
}


