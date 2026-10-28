import { describe, it, expect } from 'vitest';
import { renderToStaticMarkup } from 'react-dom/server';
import { OutputPanels } from '../components/OutputPanels';
import type { KernelOutput, ModelInput } from './types';

const model: ModelInput = {
  name: 'User',
  doc: '',
  fields: [
    { name: 'id', kind: 'Big', required: true, nullable: false, doc: '', default: null, check: { unique: true } },
    { name: 'name', kind: 'Text', required: true, nullable: false, doc: '', default: null, check: { shortest: 1, longest: 64 } },
  ],
};

function outputWith(drops: KernelOutput['drops']): KernelOutput {
  return {
    ok: true,
    jsonSchema: '{}',
    openapi: '{}',
    sql: 'CREATE TABLE x();',
    graphql: 'type X {}',
    typescript: 'export interface X {}',
    zod: 'export const XSchema = z.object({});',
    prisma: 'model X {}',
    drops,
  };
}

const noDrops: KernelOutput['drops'] = {
  jsonSchema: [], openapi: [], sql: [], graphql: [],
  typescript: [], zod: [], prisma: [],
};

describe('OutputPanels renders every projection target', () => {
  it('shows all seven projection panels', () => {
    const html = renderToStaticMarkup(
      <OutputPanels
        output={outputWith(noDrops)}
        openapiDialect="OpenApi30"
        sqlDialect="Postgres"
        model={model}
        known={[]}
      />,
    );
    for (const title of [
      'JSON Schema 2020-12',
      'OpenAPI 3.0 Schema Object',
      'SQL DDL (Postgres)',
      'GraphQL SDL',
      'TypeScript',
      'Zod',
      'Prisma',
    ]) {
      expect(html).toContain(title);
    }
  });

  it('shows a drop badge and a drop report for a target that dropped constraints', () => {
    const html = renderToStaticMarkup(
      <OutputPanels
        output={outputWith({
          ...noDrops,
          typescript: [{ field: 'id', constraint: 'unique', why: 'not expressible' }],
        })}
        openapiDialect="OpenApi30"
        sqlDialect="Postgres"
        model={model}
        known={[]}
      />,
    );
    expect(html).toContain('1 drops');
    expect(html).toContain('id.unique');
  });

  it('reports that a target carried everything when it dropped nothing', () => {
    const html = renderToStaticMarkup(
      <OutputPanels
        output={outputWith(noDrops)}
        openapiDialect="OpenApi30"
        sqlDialect="Postgres"
        model={model}
        known={[]}
      />,
    );
    expect(html).toContain('All constraints carried by this target');
  });

  it('covers all seven targets in the constraint coverage matrix', () => {
    const html = renderToStaticMarkup(
      <OutputPanels
        output={outputWith(noDrops)}
        openapiDialect="OpenApi30"
        sqlDialect="Postgres"
        model={model}
        known={[]}
      />,
    );
    expect(html).toContain('Constraint Coverage Matrix');
    for (const label of ['JSON Schema', 'OpenAPI', 'SQL', 'GraphQL', 'TypeScript', 'Zod', 'Prisma']) {
      expect(html).toContain(`>${label}</th>`);
    }
  });
});
