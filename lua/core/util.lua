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
	---@return table data # { [columnName] --> result : string[] }
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

--- convert a table to enum, e.g. core/card.lua
---@param table table # class to store the enum
---@param enum string[]
function fk.createEnum(table, enum)
	for i, v in ipairs(enum) do
		table[v] = i
	end
end
