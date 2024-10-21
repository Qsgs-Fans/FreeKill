--[[
  RequestHandler是当一名Player收到Request信息时，创建的数据结构。
  根据Player是由真人控制还是由Bot控制，该数据可能创建于客户端或者服务端。

  内容：
  * 一个Scene对象，保存着在答复该Request时，界面上所有的可操作要素
  * Player与currentRoom
  * setup(): 初始化函数

  当RequestHandler创建于客户端时，其还负责与实际显示出的UI进行通信。为了与实际
  界面进行通信，需要额外的方法与数据：

  * notifyUI(): 向qml发送所有与UI更新有关的信息
  * update(): Qml向Lua发送UI事件后，这里做出相关的处理，
              一般最后通过notifyUI反馈更新信息
  * self.change: 一次update中，产生的UI变化；设置这个的目的是当notifyUI时
              减少信息量，只将状态发生改变的元素发回客户端
  (*) 在QML中需定义applyChange函数以接收来自Lua的更改

  当RequestHandler创建于服务端时，因为并没有实际的界面，所以上述三个方法无用，
  此时与RequestHandler进行交互的就是AI逻辑代码；这些就留到以后讨论了。
--]]
--@field public data any 相关数据，需要子类自行定义一个类或者模拟类

-- 关于self.change:
-- * _new: 新创建的Item，一开始的时候UI上没显示它们
-- * _delete: 删除新创建的Item
-- * _prompt: 提示信息。实践证明prompt值得单开一个key
-- * _misc: 其他乱七八糟的需要告诉UI的信息
-- * Item类名：这类Item中某个Item发生的信息变动，change的主体部分

---@class RequestHandler: Object
---@field public room AbstractRoom
---@field public scene Scene
---@field public player Player 需要应答的玩家
---@field public prompt string 提示信息
---@field public change { [string]: Item[] } 将会传递给UI的更新数据
local RequestHandler = class("RequestHandler")

function RequestHandler:initialize(player)
  self.room = Fk:currentRoom()
  self.player = player
  -- finish只在Client执行 用于保证UI执行了某些必须执行的善后
  if ClientInstance and ClientInstance.current_request_handler then
    ClientInstance.current_request_handler:_finish()
  end
  self.room.current_request_handler = self
end

-- 进入Request之后需要做的第一步操作，对应之前UI代码中state变换
function RequestHandler:setup() end

function RequestHandler:_finish()
  if not self.finished then
    self.finished = true
    self.change = {}
    self:finish()
    self.scene:notifyUI()
  end
end

-- 因为发送答复或者超时等原因导致UI进入notactive状态时调用。
-- 只会由UI调用且只执行一次；意义主要在于清除那些传给了UI的半路新建的对象
function RequestHandler:finish() end

-- 产生UI事件后由UI触发
-- 需要实现各种合法性检验，决定需要变更状态的UI，并最终将变更反馈给真实的界面
---@param elemType string
---@param id string | integer
---@param action string
---@param data any
function RequestHandler:update(elemType, id, action, data) end

function RequestHandler:setPrompt(str)
  if not self.change then return end
  self.prompt = str
  self.change["_prompt"] = str
end

return RequestHandler
