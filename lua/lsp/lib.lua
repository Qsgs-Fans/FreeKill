-- SPDX-License-Identifier: GPL-3.0-or-later

---@meta

---@class class
---@field public static any
--- middleclass
class = {}

---@param class class|Object
---@return boolean
function class:isSubclassOf(class) end

---@class Object
---@field public class class
Object = { static = {} }

---@generic T
---@param self T
function Object:initialize(...) end

---@generic T
---@param self T
---@return T
function Object:new(...)end

---@param name string
function Object:subclass(name)end

---@param class class|Object
---@return boolean
function Object:isInstanceOf(class) end

---@param class class
---@return boolean
function Object:isSubclassOf(class) end

function Object:include(e) end

---@class json
json = {}

--- convert obj to JSON string
---@return string json
function json.encode(obj)end

--- convert JSON string to lua types
---@param str string @ JSON string to decode
---@return any
function json.decode(str)end
