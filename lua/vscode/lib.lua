---@meta

---@class class
---@field static any
--- middleclass
class = {}

---@class Object
---@field class class
Object = {}

function Object:initialize(...) end

function Object.new(...)end

---@param name string
function Object:subclass(name)end

---@param class class
---@return boolean
function Object:isInstanceOf(class) end

---@class json
json = {}

--- convert obj to JSON string
---@return string json
function json.encode(obj)end

--- convert JSON string to lua types
---@param str string # JSON string to decode
---@return table|number|string
function json.decode(str)end
