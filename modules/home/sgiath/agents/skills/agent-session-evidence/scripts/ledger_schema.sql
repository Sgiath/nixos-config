CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS runs (
  run_id TEXT PRIMARY KEY,
  started_at TEXT NOT NULL,
  finished_at TEXT,
  schema_version INTEGER NOT NULL,
  filters_json TEXT NOT NULL,
  output_dir TEXT NOT NULL,
  status TEXT NOT NULL,
  counts_json TEXT,
  coverage_json TEXT
);

CREATE TABLE IF NOT EXISTS source_items (
  harness TEXT NOT NULL,
  session_id TEXT NOT NULL,
  raw_locator TEXT NOT NULL,
  fingerprint TEXT NOT NULL,
  project_key TEXT,
  started_at TEXT,
  ended_at TEXT,
  active INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL,
  schema_version INTEGER NOT NULL,
  processed_at TEXT,
  last_run_id TEXT,
  case_ids_json TEXT,
  error TEXT,
  PRIMARY KEY (harness, session_id, raw_locator)
);

CREATE INDEX IF NOT EXISTS source_items_project_time
  ON source_items(project_key, started_at, ended_at);

CREATE TABLE IF NOT EXISTS context_files (
  project_key TEXT NOT NULL,
  path TEXT NOT NULL,
  fingerprint TEXT NOT NULL,
  status TEXT NOT NULL,
  schema_version INTEGER NOT NULL DEFAULT 1,
  processed_at TEXT,
  last_run_id TEXT,
  linked_session_ids_json TEXT,
  error TEXT,
  PRIMARY KEY (project_key, path)
);
