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
exports.deactivate = deactivate;
const vscode = __importStar(require("vscode"));
const child_process_1 = require("child_process");
const path = __importStar(require("path"));
const CLI_PATH = path.join(__dirname, '..', '..', 'cli', 'index.js');
function activate(context) {
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
        const outDir = config.get('outputDir', 'generated');
        const sqlDialect = config.get('sqlDialect', 'Postgres');
        // Validate dialect to prevent injection
        const VALID_DIALECTS = ['Postgres', 'Sqlite', 'Mysql'];
        const dialect = VALID_DIALECTS.includes(sqlDialect) ? sqlDialect : 'Postgres';
        try {
            // Use execFileSync with array args to prevent shell injection
            const result = (0, child_process_1.execFileSync)('node', [
                CLI_PATH,
                'gen', doc.uri.fsPath,
                '--out', path.join(path.dirname(doc.uri.fsPath), outDir),
                '--sql-dialect', dialect,
            ], { encoding: 'utf-8', cwd: path.dirname(doc.uri.fsPath) });
            vscode.window.showInformationMessage(`ProjDesk: ${result.trim().split('\n').pop()}`);
        }
        catch (e) {
            const msg = e instanceof Error ? e.message : String(e);
            vscode.window.showErrorMessage(`ProjDesk: ${msg}`);
        }
    });
    // Command: Generate all formats to stdout (preview in output channel)
    const generateAll = vscode.commands.registerCommand('projdesk.generateAll', async () => {
        const editor = vscode.window.activeTextEditor;
        if (!editor)
            return;
        const config = vscode.workspace.getConfiguration('projdesk');
        const sqlDialect = config.get('sqlDialect', 'Postgres');
        const openapiDialect = config.get('openapiDialect', 'OpenApi30');
        const VALID_SQL = ['Postgres', 'Sqlite', 'Mysql'];
        const VALID_OAPI = ['OpenApi30', 'OpenApi31', 'Swagger20'];
        const dialect = VALID_SQL.includes(sqlDialect) ? sqlDialect : 'Postgres';
        const oapi = VALID_OAPI.includes(openapiDialect) ? openapiDialect : 'OpenApi30';
        try {
            const result = (0, child_process_1.execFileSync)('node', [
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
        }
        catch (e) {
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
function deactivate() { }
