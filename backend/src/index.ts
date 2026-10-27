// ProjDesk API — Cloudflare Worker with D1 database
// Stores models, versions, and share links

interface Env {
  DB: D1Database;
  CORS_ORIGIN: string;
}

// CORS headers
function cors(origin: string): HeadersInit {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}

function json(data: unknown, status = 200, origin = '*'): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...cors(origin) },
  });
}

// Safe body parser
async function parseBody(request: Request): Promise<Record<string, unknown>> {
  try {
    const text = await request.text();
    console.log('Body raw:', text);
    const body = JSON.parse(text);
    console.log('Body parsed:', JSON.stringify(body));
    return (body && typeof body === 'object') ? body as Record<string, unknown> : {};
  } catch (e) {
    console.log('Parse error:', e);
    return {};
  }
}

// Generate short unique ID
function genId(): string {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
}

// Validate model fields (basic)
function validateModelFields(fields: unknown): boolean {
  return Array.isArray(fields) && fields.length <= 500;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const origin = env.CORS_ORIGIN || '*';

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: cors(origin) });
    }

    const path = url.pathname;
    const method = request.method;

    // ===== Workspace routes =====

    // POST /api/workspaces — create workspace
    if (method === 'POST' && path === '/api/workspaces') {
      const body = await parseBody(request);
      const id = genId();
      const name = typeof body.name === 'string' ? body.name.slice(0, 200) : 'My Workspace';
      await env.DB.prepare('INSERT INTO workspaces (id, name) VALUES (?1, ?2)').bind(id, name).run();
      return json({ id, name }, 201, origin);
    }

    // GET /api/workspaces/:id — get workspace with models
    const wsMatch = path.match(/^\/api\/workspaces\/(\w+)$/);
    if (method === 'GET' && wsMatch) {
      const ws = await env.DB.prepare('SELECT * FROM workspaces WHERE id = ?1').bind(wsMatch[1]).first();
      if (!ws) return json({ error: 'Workspace not found' }, 404, origin);
      const models = await env.DB.prepare('SELECT * FROM models WHERE workspace_id = ?1 ORDER BY updated_at DESC').bind(wsMatch[1]).all();
      return json({ ...ws, models: models.results }, 200, origin);
    }

    // ===== Model routes =====

    // POST /api/workspaces/:id/models — create model
    const createModelMatch = path.match(/^\/api\/workspaces\/(\w+)\/models$/);
    if (method === 'POST' && createModelMatch) {
      const body = await parseBody(request);
      const name = typeof body.name === 'string' ? body.name.slice(0, 200) : '';
      const doc = typeof body.doc === 'string' ? body.doc.slice(0, 5000) : '';
      const fields = body.fields;

      if (!name) return json({ error: 'Name required' }, 400, origin);
      if (!validateModelFields(fields)) return json({ error: 'Invalid fields' }, 400, origin);

      const id = genId();
      await env.DB.prepare(
        'INSERT INTO models (id, workspace_id, name, doc, fields_json) VALUES (?1, ?2, ?3, ?4, ?5)'
      ).bind(id, createModelMatch[1], name, doc, JSON.stringify(fields)).run();

      return json({ id, name, doc, fields }, 201, origin);
    }

    // GET /api/models/:id — get model
    const getModelMatch = path.match(/^\/api\/models\/(\w+)$/);
    if (method === 'GET' && getModelMatch) {
      const model = await env.DB.prepare('SELECT * FROM models WHERE id = ?1').bind(getModelMatch[1]).first();
      if (!model) return json({ error: 'Model not found' }, 404, origin);
      return json({
        ...model,
        fields: JSON.parse(model.fields_json as string),
      }, 200, origin);
    }

    // PUT /api/models/:id — update model
    if (method === 'PUT' && getModelMatch) {
      const body = await parseBody(request);
      const name = typeof body.name === 'string' ? body.name.slice(0, 200) : null;
      const doc = typeof body.doc === 'string' ? body.doc.slice(0, 5000) : null;
      const fields = body.fields;

      if (fields !== undefined && !validateModelFields(fields)) {
        return json({ error: 'Invalid fields' }, 400, origin);
      }

      // Save version before update
      const existing = await env.DB.prepare('SELECT * FROM models WHERE id = ?1').bind(getModelMatch[1]).first();
      if (!existing) return json({ error: 'Model not found' }, 404, origin);

      await env.DB.prepare(
        'INSERT INTO model_versions (model_id, fields_json, label) VALUES (?1, ?2, ?3)'
      ).bind(getModelMatch[1], existing.fields_json as string, 'before update').run();

      await env.DB.prepare(
        `UPDATE models SET
          name = COALESCE(?2, name),
          doc = COALESCE(?3, doc),
          fields_json = COALESCE(?4, fields_json),
          updated_at = datetime('now')
        WHERE id = ?1`
      ).bind(
        getModelMatch[1],
        name,
        doc,
        fields !== undefined ? JSON.stringify(fields) : null
      ).run();

      return json({ ok: true }, 200, origin);
    }

    // DELETE /api/models/:id
    if (method === 'DELETE' && getModelMatch) {
      await env.DB.prepare('DELETE FROM models WHERE id = ?1').bind(getModelMatch[1]).run();
      return json({ ok: true }, 200, origin);
    }

    // ===== Version routes =====

    // GET /api/models/:id/versions
    const versionsMatch = path.match(/^\/api\/models\/(\w+)\/versions$/);
    if (method === 'GET' && versionsMatch) {
      const versions = await env.DB.prepare(
        'SELECT id, label, created_at FROM model_versions WHERE model_id = ?1 ORDER BY id DESC LIMIT 50'
      ).bind(versionsMatch[1]).all();
      return json(versions.results, 200, origin);
    }

    // GET /api/versions/:id — get specific version
    const getVersionMatch = path.match(/^\/api\/versions\/(\d+)$/);
    if (method === 'GET' && getVersionMatch) {
      const version = await env.DB.prepare('SELECT * FROM model_versions WHERE id = ?1').bind(getVersionMatch[1]).first();
      if (!version) return json({ error: 'Version not found' }, 404, origin);
      return json({
        ...version,
        fields: JSON.parse(version.fields_json as string),
      }, 200, origin);
    }

    // ===== Share routes =====

    // POST /api/share — create share link
    if (method === 'POST' && path === '/api/share') {
      const raw = await request.text();
      let parsed: Record<string, unknown> = {};
      try { parsed = JSON.parse(raw); } catch { /* ignore */ }
      const data = ('data' in parsed) ? parsed.data : parsed;
      if (!data || typeof data !== 'object' || Object.keys(data).length === 0) {
        return json({ error: 'Data required', received: raw.slice(0, 80) }, 400, origin);
      }

      const code = genId();
      await env.DB.prepare(
        'INSERT INTO share_links (code, workspace_id, data_json) VALUES (?1, ?2, ?3)'
      ).bind(code, '', JSON.stringify(data)).run();

      return json({ code, url: `/share/${code}` }, 201, origin);
    }

    // GET /api/share/:code
    const shareMatch = path.match(/^\/api\/share\/(\w+)$/);
    if (method === 'GET' && shareMatch) {
      const link = await env.DB.prepare('SELECT * FROM share_links WHERE code = ?1').bind(shareMatch[1]).first();
      if (!link) return json({ error: 'Share not found' }, 404, origin);
      return json({
        data: JSON.parse(link.data_json as string),
        created_at: link.created_at,
      }, 200, origin);
    }

    // ===== Health check =====
    if (path === '/api/health') {
      return json({ status: 'ok', timestamp: new Date().toISOString() }, 200, origin);
    }

    return json({ error: 'Not found' }, 404, origin);
  },
} satisfies ExportedHandler<Env>;
