CREATE TABLE userinfo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name VARCHAR(255),
  password CHAR(64),
  avatar VARCHAR(64),
  lastLoginIp VARCHAR(64),
  banned BOOLEAN
);

CREATE TABLE banip (
  ip VARCHAR(64)
);
