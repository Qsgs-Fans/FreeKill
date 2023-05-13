/* SPDX-License-Identifier: GPL-3.0-or-later */

CREATE TABLE IF NOT EXISTS packages (
  name VARCHAR(128),
  url VARCHAR(255),
  hash CHAR(40),
  enabled BOOLEAN
);
