SmartAI:setSkillAI("ganglie", {
  think = function(self, ai)
    -- 刚烈的think中要处理两种情况：一是askForSkillInvoke的确定取消，二是被刚烈的人决定是否弃置2牌
    if ai:getPrompt():startsWith("#AskForDiscard") then
      -- 权衡一下弃牌与扣血的收益
      -- local cancel_val = 模拟自己扣血的收益
      -- local ok_val = 模拟弃两张最垃圾牌的收益
      --   比如说，等于discard_skill_ai:think()的收益什么的
      -- if ok_val > cancel_val then
      --   return ai:doOKButton()
      -- else
      --   return ""
      -- end
    else
      -- 模拟一下self.skill:use 计算收益是否为正
      return false
    end
  end,
})

SmartAI:setTriggerSkillAI("dawu", {
  correct_func = function(self, logic, event, target, player, data)
    if event ~= fk.DamageInflicted then return end
    return self.skill:triggerable(event, target, player, data)
  end,
})

--[=[
if UsingNewCore then
  require "standard.ai.aux_skills"
else
  require "packages.standard.ai.aux_skills"
end

local true_invoke = { skill_invoke = true }
local enemy_damage_invoke = {
  skill_invoke = function(skill, ai)
    local room = ai.room
    local logic = room.logic

    local event = logic:getCurrentEvent()
    local dmg = event.data[1]
    return ai:isEnemy(dmg.from)
  end
}
---@type SmartAISkillSpec
local active_random_select_card = {
  will_use = Util.TrueFunc,
  ---@param skill ViewAsSkill
  choose_cards = function(skill, ai)
    repeat
      local cids = ai:getEnabledCards()
      if #cids == 0 then return ai:okButtonEnabled() end
      ai:selectCard(cids[1], true)
    until ai:okButtonEnabled() or ai:hasEnabledTarget()
    return true
  end,
}

local use_to_enemy = fk.ai_skills["__use_to_enemy"]
local use_to_friend = fk.ai_skills["__use_to_friend"]
local just_use = fk.ai_skills["__just_use"]

-- 魏国

SmartAI:setSkillAI("jianxiong", true_invoke)
-- TODO: hujia

-- TODO: guicai 关于如何界定判定的好坏 需要向AI中单独说明
SmartAI:setSkillAI("fankui", enemy_damage_invoke)

SmartAI:setSkillAI("ganglie", {
  skill_invoke = function(skill, ai)
    local room = ai.room
    local logic = room.logic

    local event = logic:getCurrentEvent()
    local dmg = event.data[1]
    return ai:isEnemy(dmg.from)
  end,
  choose_cards = function(skill, ai)
    local cards = ai:getEnabledCards()
    if #cards > 2 then
      for i = 1, 2 do ai:selectCard(cards[i], true) end
      return true
    end
    return false -- 直接按取消键
  end,
  -- choose_targets只有个按ok 复用默认
})

SmartAI:setSkillAI("tuxi", {
  choose_targets = function(skill, ai)
    local targets = ai:getEnabledTargets()
    local i = 0
    for _, p in ipairs(targets) do
      if ai:isEnemy(p) then
        ai:selectTarget(p, true)
        i = i + 1
        if i >= 2 then return ai:doOKButton() end
      end
    end
  end
})

SmartAI:setSkillAI("luoyi", { skill_invoke = false })

SmartAI:setSkillAI("tiandu", true_invoke)
SmartAI:setSkillAI("yiji", {
  skill_invoke = true,
  -- ask_active = function
})

SmartAI:setSkillAI("luoshen", true_invoke)
SmartAI:setSkillAI("qingguo", active_random_select_card)

-- 蜀国
SmartAI:setSkillAI("rende", active_random_select_card)
SmartAI:setSkillAI("rende", use_to_friend)

-- TODO: jijiang
SmartAI:setSkillAI("wusheng", active_random_select_card)

-- TODO: guanxing

-- TODO: longdan
SmartAI:setSkillAI("longdan", active_random_select_card)

SmartAI:setSkillAI("tieqi", {
  skill_invoke = function(skill, ai)
    local room = ai.room
    local logic = room.logic

    -- 询问反馈时，处于on_cost环节，当前事件必是damage且有from
    local event = logic:getCurrentEvent()
    local use = event.data[1] ---@type CardUseStruct
    return table.find(use.tos, function(t)
      return ai:isEnemy(room:getPlayerById(t[1]))
    end)
  end
})

SmartAI:setSkillAI("jizhi", true_invoke)

-- 吴国
SmartAI:setSkillAI("zhiheng", {
  choose_cards = function(self, ai)
    for _, cid in ipairs(ai:getEnabledCards()) do
      ai:selectCard(cid, true)
    end
    return true
  end,
})
SmartAI:setSkillAI("zhiheng", just_use)

-- TODO: qixi
SmartAI:setSkillAI("qixi", active_random_select_card)

SmartAI:setSkillAI("keji", true_invoke)

SmartAI:setSkillAI("kurou", just_use)

SmartAI:setSkillAI("yingzi", true_invoke)

SmartAI:setSkillAI("fanjian", use_to_enemy)

SmartAI:setSkillAI("guose", active_random_select_card)
-- TODO: liuli

SmartAI:setSkillAI("lianying", true_invoke)

SmartAI:setSkillAI("xiaoji", true_invoke)

SmartAI:setSkillAI("jieyin", active_random_select_card)
SmartAI:setSkillAI("jieyin", use_to_friend)

-- 群雄
SmartAI:setSkillAI("qingnang", active_random_select_card)
SmartAI:setSkillAI("qingnang", use_to_friend)

-- TODO: jijiu
SmartAI:setSkillAI("qingnang", active_random_select_card)

-- TODO: lijian
SmartAI:setSkillAI("biyue", true_invoke)
--]=]
