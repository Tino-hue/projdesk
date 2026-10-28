import * as vscode from 'vscode';
import { execFileSync } from 'child_process';
import * as path from 'path';

const CLI_PATH = path.join(__dirname, '..', '..', 'cli', 'index.js');
const WASM_PATH = path.join(__dirname, '..', '..', 'web', 'public', 'projdesk.wasm');

export function activate(context: vscode.ExtensionContext) {
  console.log('ProjDesk extension activated');

  // --- helpers ---

  function currentFile(): vscode.TextDocument | undefined {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
      vscode.window.showErrorMessage('ProjDesk: No active editor');
      return undefined;
    }
    return editor.document;
  }

  function isModelFile(doc: vscode.TextDocument): boolean {
    return doc.languageId === 'json' || doc.languageId === 'projdesk';
  }

  function runCli(args: string[], cwd: string): string {
    return execFileSync('node', [CLI_PATH, ...args], {
      encoding: 'utf-8',
      cwd,
    });
  }

  // --- commands ---

  const generate = vscode.commands.registerCommand('projdesk.generate', async () => {
    const doc = currentFile();
    if (!doc) return;
    if (!isModelFile(doc)) {
      vscode.window.showErrorMessage('ProjDesk: Current file is not a model');
      return;
    }

    const config = vscode.workspace.getConfiguration('projdesk');
    const outDir = config.get<string>('outputDir', 'generated');
    const sqlDialect = config.get<string>('sqlDialect', 'Postgres');
    const VALID_DIALECTS = ['Postgres', 'Sqlite', 'Mysql'];
    const dialect = VALID_DIALECTS.includes(sqlDialect) ? sqlDialect : 'Postgres';

    try {
      const result = runCli(
        ['gen', doc.uri.fsPath, '--out', path.join(path.dirname(doc.uri.fsPath), outDir), '--sql-dialect', dialect],
        path.dirname(doc.uri.fsPath),
      );
      vscode.window.showInformationMessage(`ProjDesk: ${result.trim().split('\n').pop()}`);
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      vscode.window.showErrorMessage(`ProjDesk: ${msg}`);
    }
  });

  const generateAll = vscode.commands.registerCommand('projdesk.generateAll', async () => {
    const doc = currentFile();
    if (!doc) return;

    const config = vscode.workspace.getConfiguration('projdesk');
    const sqlDialect = config.get<string>('sqlDialect', 'Postgres');
    const openapiDialect = config.get<string>('openapiDialect', 'OpenApi30');
    const VALID_SQL = ['Postgres', 'Sqlite', 'Mysql'];
    const VALID_OAPI = ['OpenApi30', 'OpenApi31', 'Swagger20'];
    const dialect = VALID_SQL.includes(sqlDialect) ? sqlDialect : 'Postgres';
    const oapi = VALID_OAPI.includes(openapiDialect) ? openapiDialect : 'OpenApi30';

    try {
      const result = runCli(
        ['gen', doc.uri.fsPath, '--stdout', '--sql-dialect', dialect, '--openapi-dialect', oapi],
        path.dirname(doc.uri.fsPath),
      );
      const channel = vscode.window.createOutputChannel('ProjDesk');
      channel.clear();
      channel.appendLine(result);
      channel.show();
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      vscode.window.showErrorMessage(`ProjDesk: ${msg}`);
    }
  });

  const preview = vscode.commands.registerCommand('projdesk.preview', () => {
    vscode.env.openExternal(vscode.Uri.parse('https://tino-hue.github.io/projdesk/'));
  });

  const verify = vscode.commands.registerCommand('projdesk.verify', async () => {
    const doc = currentFile();
    if (!doc) return;
    try {
      const result = runCli(['verify', doc.uri.fsPath], path.dirname(doc.uri.fsPath));
      vscode.window.showInformationMessage(`ProjDesk: ${result.trim().split('\n').pop()}`);
    } catch (e: unknown) {
      // non-zero exit means issues were found — show them
      const msg = e instanceof Error ? e.message : String(e);
      const stdout = (e as { stdout?: string }).stdout ?? '';
      if (stdout) {
        const channel = vscode.window.createOutputChannel('ProjDesk');
        channel.clear();
        channel.appendLine(stdout);
        channel.show();
      }
      vscode.window.showErrorMessage(`ProjDesk: ${msg}`);
    }
  });

  // --- side panel preview ---

  const panel = vscode.window.createWebviewPanel(
    'projdesk.preview',
    'ProjDesk',
    vscode.ViewColumn.Beside,
    { enableScripts: true, retainContextWhenHidden: true },
  );

  panel.webview.html = previewHtml('Open a model file and press refresh.');

  const refresh = vscode.commands.registerCommand('projdesk.refreshPreview', async () => {
    const doc = vscode.window.activeTextEditor?.document;
    if (!doc || !isModelFile(doc)) {
      panel.webview.html = previewHtml('Open a model file (.json or .dsl) to preview it.');
      return;
    }
    try {
      const result = runCli(
        ['gen', doc.uri.fsPath, '--stdout'],
        path.dirname(doc.uri.fsPath),
      );
      panel.webview.html = previewHtml(result);
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      panel.webview.html = previewHtml(`Error: ${msg}`);
    }
  });

  context.subscriptions.push(generate, generateAll, preview, verify, refresh, panel);
}

/** Build the preview webview HTML from the CLI's stdout */
function previewHtml(body: string): string {
  const escaped = body
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
  return `<!DOCTYPE html>
<html>
<head>
<style>
  body {
    font-family: 'JetBrains Mono', 'SF Mono', Consolas, monospace;
    font-size: 11px;
    line-height: 1.6;
    padding: 12px;
    background: var(--vscode-editor-background);
    color: var(--vscode-editor-foreground);
    white-space: pre-wrap;
    word-break: break-word;
  }
  h3 {
    font-family: var(--vscode-font-family);
    font-size: 12px;
    margin: 16px 0 6px;
    padding-bottom: 4px;
    border-bottom: 1px solid var(--vscode-panel-border);
  }
  h3:first-child { margin-top: 0; }
  .key { color: #9cdcfe; }
  .str { color: #ce9178; }
  .num { color: #b5cea8; }
  .lit { color: #569cd6; }
  .kw { color: #c586c0; }
</style>
</head>
<body>${highlightJson(escaped)}</body>
</html>`;
}

/** Minimal JSON syntax highlighting for the preview */
function highlightJson(escaped: string): string {
  return escaped
    .replace(
      /("(\\.|[^"\\])*")(\s*:)/g,
      '<span class="key">$1</span>$3',
    )
    .replace(/"(\\.|[^"\\])*"/g, '<span class="str">"$1"</span>')
    .replace(/\b(true|false|null)\b/g, '<span class="lit">$1</span>')
    .replace(/\b(-?\d+\.?\d*)\b/g, '<span class="num">$1</span>');
}
