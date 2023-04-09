/* SPDX-License-Identifier: GPL-3.0-or-later */

CREATE TABLE userinfo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name VARCHAR(255),
  password CHAR(64),
  salt CHAR(8),
  avatar VARCHAR(64),
  lastLoginIp VARCHAR(64),
  banned BOOLEAN
);

CREATE TABLE banip (
  ip VARCHAR(64)
);
