require "packages.standard.ai.aux_skills"

-- 魏国

fk.ai_skill_invoke["jianxiong"] = true
-- TODO: hujia
-- TODO: guicai 关于如何界定判定的好坏 需要向AI中单独说明

fk.ai_skill_invoke["fankui"] = function(self)
  local room = self.room
  local logic = room.logic

  -- 询问反馈时，处于on_cost环节，当前事件必是damage且有from
  local event = logic:getCurrentEvent()
  local dmg = event.data[1]
  return self:isEnemy(dmg.from)
end

fk.ai_skill_invoke["ganglie"] = fk.ai_skill_invoke["fankui"]

-- TODO: tuxi

fk.ai_skill_invoke["luoyi"] = function(self)
  return false
end

fk.ai_skill_invoke["tiandu"] = true

-- TODO: yiji

fk.ai_skill_invoke["luoshen"] = true

-- TODO: qingguo

-- 蜀国
-- TODO: rende
-- TODO: jijiang
-- TODO: wusheng
-- TODO: guanxing
-- TODO: longdan

fk.ai_skill_invoke["tieqi"] = function(self)
  local room = self.room
  local logic = room.logic

  -- 询问反馈时，处于on_cost环节，当前事件必是damage且有from
  local event = logic:getCurrentEvent()
  local use = event.data[1] ---@type CardUseStruct
  return table.find(use.tos, function(t)
    return self:isEnemy(room:getPlayerById(t[1]))
  end)
end

fk.ai_skill_invoke["jizhi"] = true

-- 吴国
-- TODO: zhiheng
-- TODO: qixi

fk.ai_skill_invoke["keji"] = true

-- TODO: kurou

fk.ai_skill_invoke["yingzi"] = true

-- TODO: fanjian
-- TODO: guose
-- TODO: liuli

fk.ai_skill_invoke["lianying"] = true
fk.ai_skill_invoke["xiaoji"] = true

-- TODO: jieyin

-- 群雄
-- TODO: qingnang
-- TODO: jijiu
-- TODO: wushuang
-- TODO: lijian
fk.ai_skill_invoke["biyue"] = true
