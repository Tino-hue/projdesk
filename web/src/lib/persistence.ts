// localStorage persistence for models and settings

const STORAGE_KEY = 'projdesk_state';

interface SavedState {
  models: { id: string; model: unknown }[];
  activeId: string;
  openapiDialect: string;
  sqlDialect: string;
}

export function saveState(state: SavedState): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch {
    // storage full or unavailable
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

