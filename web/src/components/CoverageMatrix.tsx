import type { DropReason } from '../lib/types';

interface Props {
  drops: {
    jsonSchema: DropReason[];
    openapi: DropReason[];
    sql: DropReason[];
    graphql: DropReason[];
  };
}

const CONSTRAINTS = [
  'least', 'most', 'over', 'under', 'step',
  'shortest', 'longest', 'pattern', 'format',
  'options', 'distinct', 'unique',
];

const TARGETS = [
  { key: 'jsonSchema', label: 'JSON Schema' },
  { key: 'openapi', label: 'OpenAPI' },
  { key: 'sql', label: 'SQL' },
  { key: 'graphql', label: 'GraphQL' },
] as const;

export function CoverageMatrix({ drops }: Props) {
  return (
    <details className="mx-4 mb-4 text-xs">
      <summary className="cursor-pointer text-slate-500 select-none font-medium">
        Constraint Coverage Matrix (which target carries which constraint)
      </summary>
      <div className="mt-2 overflow-x-auto">
        <table className="w-full border-collapse">
          <thead>
            <tr>
              <th className="border border-slate-200 px-2 py-1 text-left bg-slate-50">Constraint</th>
              {TARGETS.map((t) => (
                <th key={t.key} className="border border-slate-200 px-2 py-1 text-center bg-slate-50">{t.label}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {CONSTRAINTS.map((c) => (
              <tr key={c}>
                <td className="border border-slate-200 px-2 py-1 font-mono">{c}</td>
                {TARGETS.map((t) => {
                  const isDropped = drops[t.key].some((d) => d.constraint === c);
                  return (
                    <td key={t.key} className="border border-slate-200 px-2 py-1 text-center">
                      {isDropped ? (
                        <span className="text-red-500 font-bold" title={drops[t.key].find((d) => d.constraint === c)?.why}>✗</span>
                      ) : (
                        <span className="text-emerald-500 font-bold">✓</span>
                      )}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </details>
  );
}
