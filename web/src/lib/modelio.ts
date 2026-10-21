import type { ModelInput } from './types';

/** Export model definition as JSON string */
export function exportModel(model: ModelInput): string {
  return JSON.stringify(model, null, 2);
}

/** Parse model definition from JSON string */
export function importModel(json: string): ModelInput | null {
  try {
    const parsed = JSON.parse(json);
    if (typeof parsed.name !== 'string' || !Array.isArray(parsed.fields)) return null;
    return {
      name: parsed.name,
      doc: parsed.doc ?? '',
      fields: parsed.fields.map((f: Record<string, unknown>) => ({
        name: String(f.name ?? ''),
        kind: f.kind ?? 'Text',
        required: f.required !== false,
        nullable: f.nullable === true,
        doc: String(f.doc ?? ''),
        default: f.default ?? null,
        check: f.check ?? {},
      })),
    };
  } catch {
    return null;
  }
}

/** Download model as .json file */
export function downloadModel(model: ModelInput) {
  const json = exportModel(model);
  const blob = new Blob([json], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${model.name || 'model'}.json`;
  a.click();
  URL.revokeObjectURL(url);
}
