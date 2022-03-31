-- load types for extension

SkillCard = require "core.card_type.skill"
BasicCard = require "core.card_type.basic"
TrickCard = require "core.card_type.trick"
EquipCard = require "core.card_type.equip"

TriggerSkill = require "core.skill_type.trigger"

---@param spec table
---@return BasicCard
function fk.CreateBasicCard(spec)
    assert(type(spec.name) == "string" or type(spec.class_name) == "string")
	if not spec.name then spec.name = spec.class_name
	elseif not spec.class_name then spec.class_name = spec.name end
	if spec.suit then assert(type(spec.suit) == "number") end
	if spec.number then assert(type(spec.number) == "number") end

    local card = BasicCard:new(spec.name, spec.suit, spec.number)
    return card
end

---@param spec table
---@return TrickCard
function fk.CreateTrickCard(spec)
    assert(type(spec.name) == "string" or type(spec.class_name) == "string")
	if not spec.name then spec.name = spec.class_name
	elseif not spec.class_name then spec.class_name = spec.name end
	if spec.suit then assert(type(spec.suit) == "number") end
	if spec.number then assert(type(spec.number) == "number") end

    local card = TrickCard:new(spec.name, spec.suit, spec.number)
    return card
end

---@param spec table
---@return EquipCard
function fk.CreateEquipCard(spec)
    assert(type(spec.name) == "string" or type(spec.class_name) == "string")
	if not spec.name then spec.name = spec.class_name
	elseif not spec.class_name then spec.class_name = spec.name end
	if spec.suit then assert(type(spec.suit) == "number") end
	if spec.number then assert(type(spec.number) == "number") end

    local card = EquipCard:new(spec.name, spec.suit, spec.number)
    return card
end

---@param spec table
---@return TriggerSkill
function fk.CreateTriggerSkill(spec)
	assert(type(spec.name) == "string")
	assert(type(spec.on_trigger) == "function")
	if spec.frequency then assert(type(spec.frequency) == "number") end

	local frequency = spec.frequency or Skill.NotFrequent
	---@type TriggerSkill
	local skill = TriggerSkill:new(spec.name, frequency)

	if type(spec.events) == "number" then
		table.insert(skill.events, spec.events)
	elseif type(spec.events) == "table" then
		for _, event in ipairs(spec.events) do
			table.insert(skill.events, event)
		end
	end

	if type(spec.refresh_events) == "number" then
		table.insert(skill.refresh_events, spec.refresh_events)
	elseif type(spec.refresh_events) == "table" then
		for _, event in ipairs(spec.refresh_events) do
			table.insert(skill.refresh_events, event)
		end
	end

	if type(spec.global) == "boolean" then skill.global = spec.global end

	skill.trigger = spec.on_trigger

	if spec.can_trigger then
		skill.triggerable = spec.can_trigger
	end

	if spec.can_refresh then
		skill.canRefresh = spec.can_refresh
	end

	if type(spec.priority) == "number" then
		for _, event in pairs(spec.priority) do
			skill.priority_table[event] = spec.priority
		end
	elseif type(spec.priority) == "table" then
		for event, priority in pairs(spec.priority) do
			skill.priority_table[event] = priority
		end
	end
	return skill
end
