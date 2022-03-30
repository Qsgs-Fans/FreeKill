---@meta

---@class freekill.SQLite3
SQLite3 = {}

---@param filename string
---@return freekill.SQLite3
function freekill.OpenDatabase(filename)end

---@param db freekill.SQLite3
---@param sql string
---@return string jsonData
function freekill.SelectFromDb(db, sql)end

---@param db freekill.SQLite3
---@param sql string
function freekill.ExecSQL(db, sql)end

---@param db freekill.SQLite3
function freekill.CloseDatabase(db)end
