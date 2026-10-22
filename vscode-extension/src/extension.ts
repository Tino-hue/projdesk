import * as vscode from 'vscode';
import { execFileSync } from 'child_process';
import * as path from 'path';

const CLI_PATH = path.join(__dirname, '..', '..', 'cli', 'index.js');

export function activate(context: vscode.ExtensionContext) {
  console.log('ProjDesk extension activated');

  // Command: Generate projections from current JSON file
  const generate = vscode.commands.registerCommand('projdesk.generate', async () => {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
      vscode.window.showErrorMessage('ProjDesk: No active editor');
      return;
    }
    const doc = editor.document;
    if (doc.languageId !== 'json') {
      vscode.window.showErrorMessage('ProjDesk: Current file is not JSON');
      return;
    }

    const config = vscode.workspace.getConfiguration('projdesk');
    const outDir = config.get<string>('outputDir', 'generated');
    const sqlDialect = config.get<string>('sqlDialect', 'Postgres');

    // Validate dialect to prevent injection
    const VALID_DIALECTS = ['Postgres', 'Sqlite', 'Mysql'];
    const dialect = VALID_DIALECTS.includes(sqlDialect) ? sqlDialect : 'Postgres';

    try {
      // Use execFileSync with array args to prevent shell injection
      const result = execFileSync('node', [
        CLI_PATH,
        'gen', doc.uri.fsPath,
        '--out', path.join(path.dirname(doc.uri.fsPath), outDir),
        '--sql-dialect', dialect,
      ], { encoding: 'utf-8', cwd: path.dirname(doc.uri.fsPath) });
      vscode.window.showInformationMessage(`ProjDesk: ${result.trim().split('\n').pop()}`);
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      vscode.window.showErrorMessage(`ProjDesk: ${msg}`);
    }
  });

  // Command: Generate all formats to stdout (preview in output channel)
  const generateAll = vscode.commands.registerCommand('projdesk.generateAll', async () => {
    const editor = vscode.window.activeTextEditor;
    if (!editor) return;

    const config = vscode.workspace.getConfiguration('projdesk');
    const sqlDialect = config.get<string>('sqlDialect', 'Postgres');
    const openapiDialect = config.get<string>('openapiDialect', 'OpenApi30');

    const VALID_SQL = ['Postgres', 'Sqlite', 'Mysql'];
    const VALID_OAPI = ['OpenApi30', 'OpenApi31', 'Swagger20'];
    const dialect = VALID_SQL.includes(sqlDialect) ? sqlDialect : 'Postgres';
    const oapi = VALID_OAPI.includes(openapiDialect) ? openapiDialect : 'OpenApi30';

    try {
      const result = execFileSync('node', [
        CLI_PATH,
        'gen', editor.document.uri.fsPath,
        '--stdout',
        '--sql-dialect', dialect,
        '--openapi-dialect', oapi,
      ], { encoding: 'utf-8', cwd: path.dirname(editor.document.uri.fsPath) });
      const channel = vscode.window.createOutputChannel('ProjDesk');
      channel.clear();
      channel.appendLine(result);
      channel.show();
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      vscode.window.showErrorMessage(`ProjDesk: ${msg}`);
    }
  });

  // Command: Open ProjDesk web UI
  const preview = vscode.commands.registerCommand('projdesk.preview', () => {
    vscode.env.openExternal(vscode.Uri.parse('https://tino-hue.github.io/projdesk/'));
  });

  context.subscriptions.push(generate, generateAll, preview);
}

export function deactivate() {}
