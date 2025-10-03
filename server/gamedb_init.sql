-- SPDX-License-Identifier: GPL-3.0-or-later

CREATE TABLE IF NOT EXISTS gameSaves (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uid INTEGER NOT NULL,
  mode TEXT NOT NULL,
  data BLOB NOT NULL,
  UNIQUE(uid, mode)
);

CREATE INDEX IF NOT EXISTS idx_gameSaves_uid ON gameSaves(uid);
CREATE INDEX IF NOT EXISTS idx_gameSaves_mode ON gameSaves(mode);

CREATE TABLE IF NOT EXISTS globalSaves (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uid INTEGER NOT NULL,
  key TEXT NOT NULL,
  data BLOB NOT NULL,
  UNIQUE(uid, key)
);

CREATE INDEX IF NOT EXISTS idx_globalSaves_uid ON globalSaves(uid);
CREATE INDEX IF NOT EXISTS idx_globalSaves_key ON globalSaves(key);
