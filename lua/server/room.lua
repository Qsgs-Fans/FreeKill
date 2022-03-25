Room = class("Room")

-- Just same as "static int roomId" in cpp
-- However id 0 is for lobby, so we start at 1
local roomId = 1

function Room:initialize()
    self.id = roomId
    roomId = roomId + 1
    self.room = ServerInstace:findRoom(self.id)
end

function Room:getCProperties()
    self.name = self.room:getName()
    self.capacity = self.room:getCapacity()
end

return Room
