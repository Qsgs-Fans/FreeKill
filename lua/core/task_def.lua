---@class TaskDefSpec
---@field type string
---@field handler fun(task: Task)

---@class TaskDef: Object
---@field type string
local TaskDef = class("TaskDef")

function TaskDef:initialize(tp)
  self.type = tp
end

---@param task Task
function TaskDef.handler(task)
end

return TaskDef
