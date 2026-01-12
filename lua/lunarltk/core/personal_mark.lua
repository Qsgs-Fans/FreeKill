---@class PersonalMarkContent

---@class PersonalMarkSpec
---@field name string
---@field qml_path string
---@field mark_name string

---@class PersonalMark : PersonalMarkSpec, Object
PersonalMark = class("Base.PersonalMark")

function PersonalMark:initialize(spec)
  self.name = spec.name
  self.qml_path = spec.qml_path
  self.mark_name = spec.mark_name
end

return PersonalMark