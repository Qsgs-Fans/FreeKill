local Room = class("Room")

function Room:initialize(_room)
    self.room = _room
    self.gameFinished = false
end

-- When this function returns, the Room(C++) thread stopped.
function Room:run()
    print 'Room is running!'
    -- First, create players(Lua) from ServerPlayer(C++)
    -- Second, assign role and adjust seats
    -- Then let's choose general and start the game!
end

function Room:startGame()
    while true do 
        if self.gameFinished then break end
    end
end

function Room:gameOver()
    self.gameFinished = true
    -- dosomething
    self.room:gameOver()
end

return Room
