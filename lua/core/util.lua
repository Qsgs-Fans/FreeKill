-- the iterator of QList object
local qlist_iterator = function(list, n)
	if n < list:length() - 1 then
		return n + 1, list:at(n + 1) -- the next element of list
	end
end

function fk.qlist(list)
	return qlist_iterator, list, -1
end

function table:contains(element)
	if #self == 0 or type(self[1]) ~= type(element) then return false end
	for _, e in ipairs(self) do
		if e == element then return true end
	end
end

function table:shuffle()
	for i = #self, 2, -1 do
	  	local j = math.random(i)
	  	self[i], self[j] = self[j], self[i]
	end
end

function table:insertTable(list)
	for _, e in ipairs(list) do
		table.insert(self, e)
	end
end

function table:indexOf(value, from)
	from = from or 1
	for i = from, #self do
		if self[i] == value then return i end
	end
	return -1
end

function table:removeOne(element)
	if #self == 0 or type(self[1]) ~= type(element) then return false end

	for i = 1, #self do
		if self[i] == element then
			table.remove(self, i)
			return true
		end
	end
	return false
end

---@class Sql
Sql = {
	---@param filename string
	open = function(filename)
		return fk.OpenDatabase(filename)
	end,

	---@param db fk.SQLite3
	close = function(db)
		fk.CloseDatabase(db)
	end,

	--- Execute an SQL statement.
	---@param db fk.SQLite3
	---@param sql string
	exec = function(db, sql)
		fk.ExecSQL(db, sql)
	end,

	--- Execute a `SELECT` SQL statement.
	---@param db fk.SQLite3
	---@param sql string
	---@return table @ { [columnName] --> result : string[] }
	exec_select = function(db, sql)
		return json.decode(fk.SelectFromDb(db, sql))
	end,
}

FileIO = {
	pwd = fk.QmlBackend_pwd,
	ls = function(filename)
		if filename == nil then
			return fk.QmlBackend_ls(".")
		else
			return fk.QmlBackend_ls(filename)
		end
	end,
	cd = fk.QmlBackend_cd,
	exists = fk.QmlBackend_exists,
	isDir = fk.QmlBackend_isDir
}

os.getms = fk.GetMicroSecond

---@class Stack : Object
Stack = class("Stack")
function Stack:initialize()
	self.t = {}
	self.p = 0
end

function Stack:push(e)
	self.p = self.p + 1
	self.t[self.p] = e
end

function Stack:isEmpty()
	return self.p == 0
end

function Stack:pop()
	if self.p == 0 then return nil end
	self.p = self.p - 1
	return self.t[self.p + 1]
end


--- useful function to create enums
---
--- only use it in a terminal
---@param table string
---@param enum string[]
function CreateEnum(table, enum)
	local enum_format = "%s.%s = %d"
	for i, v in ipairs(enum) do
		print(string.format(enum_format, table, v, i))
	end
end

function switch(param, case_table)
	local case = case_table[param]
    if case then return case() end
    local def = case_table["default"]
    return def and def() or nil
end
