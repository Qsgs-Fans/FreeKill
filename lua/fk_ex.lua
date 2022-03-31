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
