// Engine panel: exposes DSL compiler, constraint solver, migration, equivalence
import { useState } from 'react';
import type { ModelInput } from '../lib/types';
import { dslProject, solveConstraints, generateMigration, checkEquivalence } from '../lib/wasm';

const DSL_EXAMPLE = `model User {
  id: Big @unique
  name: Text [shortest=1, longest=64]
  email: Text [format=email]
  age: Int @optional [least=0, under=150]
  tags: List(Text) @optional @distinct
}`;

interface Props {
  model: ModelInput;
}

export function EnginePanel({ model }: Props) {
  const [activeEngine, setActiveEngine] = useState<'dsl' | 'solver' | 'migration' | 'equiv'>('dsl');
  const [dslText, setDslText] = useState(DSL_EXAMPLE);
  const [dslOutput, setDslOutput] = useState('');
  const [solverOutput, setSolverOutput] = useState('');
  const [migrationOutput, setMigrationOutput] = useState('');
  const [equivOutput, setEquivOutput] = useState('');
  const [running, setRunning] = useState(false);

  const runDsl = async () => {
    setRunning(true);
    try {
      const result = await dslProject(dslText);
      setDslOutput(result);
    } catch (e) {
      setDslOutput('Error: ' + String(e));
    }
    setRunning(false);
  };

  const runSolver = async () => {
    setRunning(true);
    try {
      const result = await solveConstraints(JSON.stringify(model));
      setSolverOutput(result);
    } catch (e) {
      setSolverOutput('Error: ' + String(e));
    }
    setRunning(false);
  };

  const runMigration = async () => {
    setRunning(true);
    try {
      // Compare current model against a snapshot (empty fields = fresh)
      const oldModel = { ...model, fields: model.fields.slice(0, Math.max(1, model.fields.length - 1)) };
      const result = await generateMigration(JSON.stringify(oldModel), JSON.stringify(model));
      setMigrationOutput(result);
    } catch (e) {
      setMigrationOutput('Error: ' + String(e));
    }
    setRunning(false);
  };

  const runEquiv = async () => {
    setRunning(true);
    try {
      // Compare model against a relaxed copy (nullable + wider constraints)
      const relaxed = {
        ...model,
        fields: model.fields.map((f) => ({ ...f, required: false, nullable: true })),
      };
      const result = await checkEquivalence(JSON.stringify(model), JSON.stringify(relaxed));
      setEquivOutput(result);
    } catch (e) {
      setEquivOutput('Error: ' + String(e));
    }
    setRunning(false);
  };

  const engines = [
    { key: 'dsl' as const, label: 'DSL Compiler', desc: 'Modeling language -> model' },
    { key: 'solver' as const, label: 'Constraint Solver', desc: 'Conflicts & redundancy' },
    { key: 'migration' as const, label: 'Migration', desc: 'Diff + SQL ALTER' },
    { key: 'equiv' as const, label: 'Equivalence', desc: 'Subtyping & containment' },
  ];

  return (
    <details className="mx-2 sm:mx-4 mb-4 text-xs">
      <summary className="cursor-pointer text-slate-600 dark:text-slate-300 select-none font-semibold">
        MoonBit Engine Playground (5 independent engines)
      </summary>
      <div className="mt-2 space-y-2">
        {/* Engine tabs */}
        <div className="flex flex-wrap gap-1">
          {engines.map((e) => (
            <button
              key={e.key}
              onClick={() => setActiveEngine(e.key)}
              className={`px-2 py-1 rounded-md text-[11px] font-medium transition-colors ${
                activeEngine === e.key
                  ? 'bg-blue-500 text-white'
                  : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-200'
              }`}
            >
              {e.label}
            </button>
          ))}
        </div>

        {/* DSL Compiler */}
        {activeEngine === 'dsl' && (
          <div className="space-y-1.5">
            <textarea
              className="w-full h-28 px-2 py-1.5 text-[11px] font-mono border border-slate-200 dark:border-slate-700 rounded-md bg-slate-50 dark:bg-slate-900 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-1 focus:ring-blue-500/40"
              value={dslText}
              onChange={(e) => setDslText(e.target.value)}
              placeholder="model User { id: Big @unique }"
            />
            <button
              className="px-3 py-1 text-[11px] bg-blue-500 text-white rounded-md hover:bg-blue-600 disabled:opacity-50"
              onClick={runDsl}
              disabled={running}
            >
              Parse DSL
            </button>
            {dslOutput && <pre className="p-2 text-[10px] font-mono bg-slate-950 text-slate-200 rounded-md overflow-auto max-h-40 whitespace-pre-wrap">{dslOutput}</pre>}
          </div>
        )}

        {/* Solver */}
        {activeEngine === 'solver' && (
          <div className="space-y-1.5">
            <button
              className="px-3 py-1 text-[11px] bg-blue-500 text-white rounded-md hover:bg-blue-600 disabled:opacity-50"
              onClick={runSolver}
              disabled={running}
            >
              Analyze Constraints
            </button>
            {solverOutput && <pre className="p-2 text-[10px] font-mono bg-slate-950 text-slate-200 rounded-md overflow-auto max-h-40 whitespace-pre-wrap">{solverOutput}</pre>}
          </div>
        )}

        {/* Migration */}
        {activeEngine === 'migration' && (
          <div className="space-y-1.5">
            <button
              className="px-3 py-1 text-[11px] bg-blue-500 text-white rounded-md hover:bg-blue-600 disabled:opacity-50"
              onClick={runMigration}
              disabled={running}
            >
              Generate Migration (drop last field)
            </button>
            {migrationOutput && <pre className="p-2 text-[10px] font-mono bg-slate-950 text-slate-200 rounded-md overflow-auto max-h-40 whitespace-pre-wrap">{migrationOutput}</pre>}
          </div>
        )}

        {/* Equivalence */}
        {activeEngine === 'equiv' && (
          <div className="space-y-1.5">
            <button
              className="px-3 py-1 text-[11px] bg-blue-500 text-white rounded-md hover:bg-blue-600 disabled:opacity-50"
              onClick={runEquiv}
              disabled={running}
            >
              Check Equivalence (strict vs relaxed)
            </button>
            {equivOutput && <pre className="p-2 text-[10px] font-mono bg-slate-950 text-slate-200 rounded-md overflow-auto max-h-40 whitespace-pre-wrap">{equivOutput}</pre>}
          </div>
        )}
      </div>
    </details>
  );
}
