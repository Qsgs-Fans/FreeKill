---@meta

---@class fk.SQLite3
SQLite3 = {}

---@param filename string
---@return fk.SQLite3
function fk.OpenDatabase(filename)end

---@param db fk.SQLite3
---@param sql string
---@return string jsonData
function fk.SelectFromDb(db, sql)end

---@param db fk.SQLite3
---@param sql string
function fk.ExecSQL(db, sql)end

---@param db fk.SQLite3
function fk.CloseDatabase(db)end
