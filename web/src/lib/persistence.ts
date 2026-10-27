// localStorage persistence for models and settings

const STORAGE_KEY = 'projdesk_state';

interface SavedState {
  models: { id: string; model: unknown }[];
  activeId: string;
  openapiDialect: string;
  sqlDialect: string;
}

// Track tab identity for conflict detection
const TAB_ID = Math.random().toString(36).slice(2);
const TAB_STAMP_KEY = 'projdesk_tab_stamp';

export function saveState(state: SavedState): void {
  try {
    // Mark this tab as the writer
    localStorage.setItem(TAB_STAMP_KEY, JSON.stringify({ tab: TAB_ID, time: Date.now() }));
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch {
    // storage full or unavailable
  }
}

/** Check if another tab wrote more recently */
export function hasConflict(): boolean {
  try {
    const raw = localStorage.getItem(TAB_STAMP_KEY);
    if (!raw) return false;
    const stamp = JSON.parse(raw);
    // If another tab wrote within last 2 seconds, potential conflict
    return stamp.tab !== TAB_ID && (Date.now() - stamp.time) < 2000;
  } catch {
    return false;
  }
}

export function loadState(): SavedState | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const data = JSON.parse(raw);
    if (!Array.isArray(data.models) || data.models.length === 0) return null;
    if (data.models.length > 50) return null;
    return data as SavedState;
  } catch {
    return null;
  }
}

export function clearState(): void {
  try {
    localStorage.removeItem(STORAGE_KEY);
  } catch {
    // ignore
  }
}


