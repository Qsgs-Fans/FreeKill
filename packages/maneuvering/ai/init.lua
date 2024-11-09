local slash = fk.ai_skills["slash_skill"]
local just_use = fk.ai_skills["__just_use"]
local use_to_enemy = fk.ai_skills["__use_to_enemy"]
SmartAI:setSkillAI("thunder__slash_skill", slash)
SmartAI:setSkillAI("fire__slash_skill", slash)
SmartAI:setSkillAI("analeptic_skill", just_use)
SmartAI:setSkillAI("iron_chain_skill", just_use)
SmartAI:setSkillAI("fire_attack_skill", use_to_enemy)
SmartAI:setSkillAI("supply_shortage_skill", use_to_enemy)

