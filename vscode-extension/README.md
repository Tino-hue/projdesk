# ProjDesk VS Code Extension

Model engineering in the editor: syntax highlighting for the ProjDesk modeling language, one-click projection generation, and an inline preview panel.

## Features

### Syntax highlighting

`.dsl` and `.projdesk` files are highlighted with the ProjDesk grammar:

- `model` / `List` / `Dict` / `Nest` / `Ref` keywords
- `@optional` / `@nullable` / `@unique` / `@distinct` attributes
- Type names (`Bool` / `Int` / `Big` / `Text` / `Stamp` / ...)
- Constraint names (`least` / `most` / `longest` / `pattern` / ...)
- Line and block comments
- Arithmetic operators and builtins (`min` / `max` / `abs` / `ceil` / `floor`)

### Commands

| Command | Description |
|---------|-------------|
| `ProjDesk: Generate Projections` | Write the seven projections to the output directory |
| `ProjDesk: Generate All Formats` | Print all projections to the Output panel |
| `ProjDesk: Verify Model (semantics + round-trip)` | Check references, cycles, and round-trip integrity |
| `ProjDesk: Preview in Browser` | Open the ProjDesk web workbench |

### Preview panel

The **ProjDesk** side panel shows the generated projections with JSON syntax highlighting. Run `ProjDesk: refreshPreview` (bind a key to it) to update after editing.

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `projdesk.outputDir` | `generated` | Output directory for generated schemas |
| `projdesk.sqlDialect` | `Postgres` | `Postgres` / `Sqlite` / `Mysql` |
| `projdesk.openapiDialect` | `OpenApi30` | `OpenApi30` / `OpenApi31` / `Swagger20` |

## Development

```bash
cd vscode-extension
npm install
npm run compile
# Press F5 in VS Code to launch the Extension Development Host
```
