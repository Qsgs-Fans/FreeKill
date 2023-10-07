-- SPDX-License-Identifier: GPL-3.0-or-later

-- 用户基本信息

CREATE TABLE IF NOT EXISTS userinfo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name VARCHAR(255),
  password CHAR(64),
  salt CHAR(8),
  avatar VARCHAR(64),
  lastLoginIp VARCHAR(64),
  banned BOOLEAN
);

CREATE TABLE IF NOT EXISTS banip (
  ip VARCHAR(64)
);

CREATE TABLE IF NOT EXISTS uuidinfo (
  id INTEGER PRIMARY KEY,
  uuid VARCHAR(32)
);

CREATE TABLE IF NOT EXISTS banuuid (
  uuid VARCHAR(32)
);

CREATE TABLE IF NOT EXISTS friendinfo (
  id1 INTEGER,
  id2 INTEGER,
  reltype INTEGER   -- 1=好友 2=黑名单
);

-- 胜率相关

CREATE TABLE IF NOT EXISTS winRate (
  id INTEGER,
  general VARCHAR(20),
  mode VARCHAR(16),
  win INTEGER,
  lose INTEGER,
  draw INTEGER,
  PRIMARY KEY (id, general, mode)
);

CREATE TABLE IF NOT EXISTS runRate (
  id INTEGER,
  mode VARCHAR(16),
  run INTEGER,
  PRIMARY KEY (id, mode)
);

CREATE VIEW IF NOT EXISTS playerWinRate AS
  SELECT winRate.id, name, mode,
    SUM(win) AS 'win',
    SUM(lose) AS 'lose',
    SUM(draw) AS 'draw',
    SUM(win + lose + draw) AS 'total',
    ROUND(SUM(win) * 1.0 / (SUM(win + lose + draw) * 1.0) * 100, 2)
      AS 'winRate'
  FROM winRate, userinfo
  WHERE winRate.id = userinfo.id
  GROUP BY winRate.id, mode;

CREATE VIEW IF NOT EXISTS generalWinRate AS
  SELECT general, mode,
    SUM(win) AS 'win',
    SUM(lose) AS 'lose',
    SUM(draw) AS 'draw',
    SUM(win + lose + draw) AS 'total',
    ROUND(SUM(win) * 1.0 / (SUM(win + lose + draw) * 1.0) * 100, 2)
      AS 'winRate'
  FROM winRate GROUP BY general, mode;
