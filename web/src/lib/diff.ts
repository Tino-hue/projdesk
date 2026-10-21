// Model diff: compare two model snapshots and show what changed

export interface FieldDiff {
  name: string;
  type: 'added' | 'removed' | 'modified' | 'unchanged';
  changes: string[];
}

export interface ModelDiff {
  nameChange?: { from: string; to: string };
  fields: FieldDiff[];
}

export function diffModels(oldModel: { name: string; fields: unknown[] }, newModel: { name: string; fields: unknown[] }): ModelDiff {
  const oldFields = new Map<string, Record<string, unknown>>();
  const newFields = new Map<string, Record<string, unknown>>();

  for (const f of oldModel.fields as Record<string, unknown>[]) {
    if (f.name) oldFields.set(String(f.name), f);
  }
  for (const f of newModel.fields as Record<string, unknown>[]) {
    if (f.name) newFields.set(String(f.name), f);
  }

  const fields: FieldDiff[] = [];
  const allNames = new Set([...oldFields.keys(), ...newFields.keys()]);

  for (const name of allNames) {
    const oldF = oldFields.get(name);
    const newF = newFields.get(name);

    if (!oldF && newF) {
      fields.push({ name, type: 'added', changes: ['field added'] });
    } else if (oldF && !newF) {
      fields.push({ name, type: 'removed', changes: ['field removed'] });
    } else if (oldF && newF) {
      const changes: string[] = [];
      if (JSON.stringify(oldF.kind) !== JSON.stringify(newF.kind)) changes.push(`type: ${JSON.stringify(oldF.kind)} -> ${JSON.stringify(newF.kind)}`);
      if (oldF.required !== newF.required) changes.push(`required: ${oldF.required} -> ${newF.required}`);
      if (oldF.nullable !== newF.nullable) changes.push(`nullable: ${oldF.nullable} -> ${newF.nullable}`);
      if (oldF.doc !== newF.doc) changes.push('doc changed');
      if (JSON.stringify(oldF.check) !== JSON.stringify(newF.check)) {
        const oldCheck = (oldF.check as Record<string, unknown>) || {};
        const newCheck = (newF.check as Record<string, unknown>) || {};
        for (const key of new Set([...Object.keys(oldCheck), ...Object.keys(newCheck)])) {
          if (JSON.stringify(oldCheck[key]) !== JSON.stringify(newCheck[key])) {
            changes.push(`check.${key}: ${JSON.stringify(oldCheck[key] ?? null)} -> ${JSON.stringify(newCheck[key] ?? null)}`);
          }
        }
      }
      fields.push({ name, type: changes.length > 0 ? 'modified' : 'unchanged', changes });
    }
  }

  return {
    nameChange: oldModel.name !== newModel.name ? { from: oldModel.name, to: newModel.name } : undefined,
    fields: fields.sort((a, b) => a.name.localeCompare(b.name)),
  };
}
