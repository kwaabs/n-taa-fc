const STORAGE_KEY = "data-table-columns";

interface PerProjectPrefs {
  [projectId: string]: string[]; // list of visible attribute column ids
}

function load(): PerProjectPrefs {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : {};
  } catch {
    return {};
  }
}

function save(prefs: PerProjectPrefs) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(prefs));
  } catch {
    // ignore quota errors
  }
}

export function getVisibleColumns(projectId: string): string[] | null {
  const prefs = load();
  return prefs[projectId] || null;
}

export function setVisibleColumns(projectId: string, columns: string[]): void {
  const prefs = load();
  prefs[projectId] = columns;
  save(prefs);
}

export function clearColumnPrefs(projectId: string): void {
  const prefs = load();
  delete prefs[projectId];
  save(prefs);
}