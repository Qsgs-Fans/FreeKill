-- SPDX-License-Identifier: GPL-3.0-or-later

-- 此为客户端利用sqlite保存的内容
-- 目前先就只保存游戏数据

PRAGMA auto_vacuum = FULL;
PRAGMA incremental_vacuum(5);

CREATE TABLE IF NOT EXISTS myGameData (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  time INTEGER,  -- 该记录入库时的时间戳
  pid INTEGER,   -- 玩家id，玩这局游戏时我自己的id
  server_addr VARCHAR(16), -- 玩这局游戏的服务器地址 [ip:端口]
  mode VARCHAR(16),        -- 这局游戏的游戏模式
  general VARCHAR(16),     -- 这局游戏选用武将
  deputy_general VARCHAR(16),     -- 这局游戏选用的副将
  role VARCHAR(8),         -- 这局游戏中的身份
  result INTEGER           -- 游戏的胜负 1=胜 2=负 3=平
);

-- 自动保存录像：录像文件直接以blob形式存于数据库
CREATE TABLE IF NOT EXISTS myGameRecordings (
  id INTEGER PRIMARY KEY, -- gameData id
  recording BLOB          -- 录像文件的内容
);

-- 利用trigger自动删除，只保留近5000局录像
CREATE TRIGGER IF NOT EXISTS deleteOldRecordings AFTER INSERT ON myGameRecordings
BEGIN
  DELETE FROM myGameRecordings WHERE id NOT IN 
    (SELECT id FROM myGameRecordings ORDER BY id DESC LIMIT 5000);
END;

-- 自动保存复盘资料
CREATE TABLE IF NOT EXISTS myGameRoomData (
  id INTEGER PRIMARY KEY, -- gameData id
  room_data BLOB          -- 录像文件的内容
);

-- 利用trigger自动删除，只保留近50000局的终局复盘
CREATE TRIGGER IF NOT EXISTS deleteOldRoomData AFTER INSERT ON myGameRoomData
BEGIN
  DELETE FROM myGameRoomData WHERE id NOT IN 
    (SELECT id FROM myGameRoomData ORDER BY id DESC LIMIT 50000);
END;

CREATE TABLE IF NOT EXISTS starredRecording (
  id INTEGER PRIMARY KEY, -- gameData id
  replay_name VARCHAR(24), -- 对应录像文件的名字 在recording/下（保存录像按钮）
  my_comment VARCHAR(24)   -- 评语
);
