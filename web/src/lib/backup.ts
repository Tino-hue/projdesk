// Workspace backup: export/import all models + settings as a single JSON file
// Prevents data loss from localStorage clearing

import type { ModelInput } from './types';

export interface WorkspaceBackup {
  version: 1;
  timestamp: string;
  models: { id: string; model: ModelInput }[];
  activeId: string;
  settings: {
    openapiDialect: string;
    sqlDialect: string;
    theme: string;
  };
}

export function createBackup(
  models: { id: string; model: ModelInput }[],
  activeId: string,
  settings: { openapiDialect: string; sqlDialect: string; theme: string },
): WorkspaceBackup {
  return {
    version: 1,
    timestamp: new Date().toISOString(),
    models: JSON.parse(JSON.stringify(models)),
    activeId,
    settings,
  };
}

export function downloadBackup(backup: WorkspaceBackup, filename?: string) {
  const json = JSON.stringify(backup, null, 2);
  const blob = new Blob([json], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename || `projdesk-backup-${backup.timestamp.slice(0, 10)}.json`;
  a.click();
  URL.revokeObjectURL(url);
}

export function parseBackup(text: string): WorkspaceBackup | null {
  try {
    const data = JSON.parse(text);
    if (data.version !== 1) return null;
    if (!Array.isArray(data.models) || data.models.length === 0) return null;
    if (data.models.length > 50) return null;
    // Basic shape check
    for (const m of data.models) {
      if (!m.model || typeof m.model.name !== 'string') return null;
    }
    return data as WorkspaceBackup;
  } catch {
    return null;
  }
}

// ---------- Undo history persistence ----------

const HISTORY_KEY = 'projdesk_history';

export function saveHistory(entries: unknown[], pointer: number): void {
  try {
    // Keep last 30 entries to avoid localStorage bloat
    const trimmed = entries.slice(-30);
    const trimmedPointer = Math.min(pointer, trimmed.length - 1);
    localStorage.setItem(HISTORY_KEY, JSON.stringify({ entries: trimmed, pointer: trimmedPointer }));
  } catch {
    // storage full
  }
}

export function loadHistory(): { entries: unknown[]; pointer: number } | null {
  try {
    const raw = localStorage.getItem(HISTORY_KEY);
    if (!raw) return null;
    const data = JSON.parse(raw);
    if (!Array.isArray(data.entries) || data.entries.length === 0) return null;
    return { entries: data.entries, pointer: Math.max(0, Math.min(data.pointer, data.entries.length - 1)) };
  } catch {
    return null;
  }
}

export function clearHistory(): void {
  try { localStorage.removeItem(HISTORY_KEY); } catch { /* ignore */ }
}

// ---------- Auto-backup reminder ----------

const BACKUP_KEY = 'projdesk_last_backup';

export function shouldRemindBackup(): boolean {
  try {
    const last = localStorage.getItem(BACKUP_KEY);
    if (!last) return true;
    const days = (Date.now() - Number(last)) / (1000 * 60 * 60 * 24);
    return days > 3; // remind every 3 days
  } catch {
    return false;
  }
}

export function markBackupDone(): void {
  try { localStorage.setItem(BACKUP_KEY, String(Date.now())); } catch { /* ignore */ }
}
