// Undo/Redo history manager
// Stores model states and allows stepping back/forward

interface HistoryEntry {
  models: string; // JSON serialized models
  activeId: string;
}

export class HistoryManager {
  private stack: HistoryEntry[] = [];
  private pointer = -1;
  private maxDepth = 50;

  constructor() {
    // Restore from localStorage
    try {
      const raw = localStorage.getItem('projdesk_history');
      if (raw) {
        const data = JSON.parse(raw);
        if (Array.isArray(data.stack) && data.stack.length > 0) {
          this.stack = data.stack.slice(-this.maxDepth);
          this.pointer = Math.max(0, Math.min(data.pointer ?? this.stack.length - 1, this.stack.length - 1));
        }
      }
    } catch { /* ignore */ }
  }

  private persist(): void {
    try {
      localStorage.setItem('projdesk_history', JSON.stringify({ stack: this.stack.slice(-30), pointer: this.pointer }));
    } catch { /* storage full */ }
  }

  push(entry: HistoryEntry): void {
    this.stack = this.stack.slice(0, this.pointer + 1);
    this.stack.push(entry);
    if (this.stack.length > this.maxDepth) {
      this.stack.shift();
    } else {
      this.pointer++;
    }
    this.persist();
  }

  undo(): HistoryEntry | null {
    if (this.pointer <= 0) return null;
    this.pointer--;
    this.persist();
    return this.stack[this.pointer] ?? null;
  }

  redo(): HistoryEntry | null {
    if (this.pointer >= this.stack.length - 1) return null;
    this.pointer++;
    this.persist();
    return this.stack[this.pointer] ?? null;
  }

  canUndo(): boolean {
    return this.pointer > 0;
  }

  canRedo(): boolean {
    return this.pointer < this.stack.length - 1;
  }

  clear(): void {
    this.stack = [];
    this.pointer = -1;
  }
}

// URL hash encoding/decoding for shareable links
export function encodeToHash(data: { models: unknown[]; activeId: string; openapiDialect: string; sqlDialect: string }): string {
  const json = JSON.stringify(data);
  return btoa(encodeURIComponent(json)).replace(/=+$/, '');
}

export function decodeFromHash(hash: string): { models: unknown[]; activeId: string; openapiDialect: string; sqlDialect: string } | null {
  if (!hash || hash.length > 500000) return null;
  try {
    const json = decodeURIComponent(atob(hash));
    if (json.length > 1000000) return null;
    return JSON.parse(json);
  } catch {
    return null;
  }
}


