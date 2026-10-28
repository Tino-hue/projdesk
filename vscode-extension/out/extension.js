"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.activate = activate;
const vscode = __importStar(require("vscode"));
const child_process_1 = require("child_process");
const path = __importStar(require("path"));
const CLI_PATH = path.join(__dirname, '..', '..', 'cli', 'index.js');
const WASM_PATH = path.join(__dirname, '..', '..', 'web', 'public', 'projdesk.wasm');
function activate(context) {
    console.log('ProjDesk extension activated');
    // --- helpers ---
    function currentFile() {
        const editor = vscode.window.activeTextEditor;
        if (!editor) {
            vscode.window.showErrorMessage('ProjDesk: No active editor');
            return undefined;
        }
        return editor.document;
    }
    function isModelFile(doc) {
        return doc.languageId === 'json' || doc.languageId === 'projdesk';
    }
    function runCli(args, cwd) {
        return (0, child_process_1.execFileSync)('node', [CLI_PATH, ...args], {
            encoding: 'utf-8',
            cwd,
        });
    }
    // --- commands ---
    const generate = vscode.commands.registerCommand('projdesk.generate', async () => {
        const doc = currentFile();
        if (!doc)
            return;
        if (!isModelFile(doc)) {
            vscode.window.showErrorMessage('ProjDesk: Current file is not a model');
            return;
        }
        const config = vscode.workspace.getConfiguration('projdesk');
        const outDir = config.get('outputDir', 'generated');
        const sqlDialect = config.get('sqlDialect', 'Postgres');
        const VALID_DIALECTS = ['Postgres', 'Sqlite', 'Mysql'];
        const dialect = VALID_DIALECTS.includes(sqlDialect) ? sqlDialect : 'Postgres';
        try {
            const result = runCli(['gen', doc.uri.fsPath, '--out', path.join(path.dirname(doc.uri.fsPath), outDir), '--sql-dialect', dialect], path.dirname(doc.uri.fsPath));
            vscode.window.showInformationMessage(`ProjDesk: ${result.trim().split('\n').pop()}`);
        }
        catch (e) {
            const msg = e instanceof Error ? e.message : String(e);
            vscode.window.showErrorMessage(`ProjDesk: ${msg}`);
        }
    });
    const generateAll = vscode.commands.registerCommand('projdesk.generateAll', async () => {
        const doc = currentFile();
        if (!doc)
            return;
        const config = vscode.workspace.getConfiguration('projdesk');
        const sqlDialect = config.get('sqlDialect', 'Postgres');
        const openapiDialect = config.get('openapiDialect', 'OpenApi30');
        const VALID_SQL = ['Postgres', 'Sqlite', 'Mysql'];
        const VALID_OAPI = ['OpenApi30', 'OpenApi31', 'Swagger20'];
        const dialect = VALID_SQL.includes(sqlDialect) ? sqlDialect : 'Postgres';
        const oapi = VALID_OAPI.includes(openapiDialect) ? openapiDialect : 'OpenApi30';
        try {
            const result = runCli(['gen', doc.uri.fsPath, '--stdout', '--sql-dialect', dialect, '--openapi-dialect', oapi], path.dirname(doc.uri.fsPath));
            const channel = vscode.window.createOutputChannel('ProjDesk');
            channel.clear();
            channel.appendLine(result);
            channel.show();
        }
        catch (e) {
            const msg = e instanceof Error ? e.message : String(e);
            vscode.window.showErrorMessage(`ProjDesk: ${msg}`);
        }
    });
    const preview = vscode.commands.registerCommand('projdesk.preview', () => {
        vscode.env.openExternal(vscode.Uri.parse('https://tino-hue.github.io/projdesk/'));
    });
    const verify = vscode.commands.registerCommand('projdesk.verify', async () => {
        const doc = currentFile();
        if (!doc)
            return;
        try {
            const result = runCli(['verify', doc.uri.fsPath], path.dirname(doc.uri.fsPath));
            vscode.window.showInformationMessage(`ProjDesk: ${result.trim().split('\n').pop()}`);
        }
        catch (e) {
            // non-zero exit means issues were found — show them
            const msg = e instanceof Error ? e.message : String(e);
            const stdout = e.stdout ?? '';
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
    const panel = vscode.window.createWebviewPanel('projdesk.preview', 'ProjDesk', vscode.ViewColumn.Beside, { enableScripts: true, retainContextWhenHidden: true });
    panel.webview.html = previewHtml('Open a model file and press refresh.');
    const refresh = vscode.commands.registerCommand('projdesk.refreshPreview', async () => {
        const doc = vscode.window.activeTextEditor?.document;
        if (!doc || !isModelFile(doc)) {
            panel.webview.html = previewHtml('Open a model file (.json or .dsl) to preview it.');
            return;
        }
        try {
            const result = runCli(['gen', doc.uri.fsPath, '--stdout'], path.dirname(doc.uri.fsPath));
            panel.webview.html = previewHtml(result);
        }
        catch (e) {
            const msg = e instanceof Error ? e.message : String(e);
            panel.webview.html = previewHtml(`Error: ${msg}`);
        }
    });
    context.subscriptions.push(generate, generateAll, preview, verify, refresh, panel);
}
/** Build the preview webview HTML from the CLI's stdout */
function previewHtml(body) {
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
function highlightJson(escaped) {
    return escaped
        .replace(/("(\\.|[^"\\])*")(\s*:)/g, '<span class="key">$1</span>$3')
        .replace(/"(\\.|[^"\\])*"/g, '<span class="str">"$1"</span>')
        .replace(/\b(true|false|null)\b/g, '<span class="lit">$1</span>')
        .replace(/\b(-?\d+\.?\d*)\b/g, '<span class="num">$1</span>');
}
