# ProjDesk VS Code Extension

Generate 7 schema projections from a model JSON, directly inside VS Code.

## Commands

| Command | Description |
|---------|-------------|
| `ProjDesk: Generate Projections` | Write schema files to output directory |
| `ProjDesk: Generate All Formats` | Preview all formats in Output panel |
| `ProjDesk: Preview in Browser` | Open ProjDesk web UI |

## Usage

1. Open a model JSON file (e.g. `model.json`)
2. Right-click → `ProjDesk: Generate Projections`
3. Or Ctrl+Shift+P → `ProjDesk: Generate All Formats`

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `projdesk.outputDir` | `generated` | Output directory |
| `projdesk.sqlDialect` | `Postgres` | SQL dialect |
| `projdesk.openapiDialect` | `OpenApi30` | OpenAPI dialect |

## Development

```bash
cd vscode-extension
npm install
npm run compile
# Press F5 in VS Code to launch Extension Development Host
```
