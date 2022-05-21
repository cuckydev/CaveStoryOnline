door = class("door")

function door:initialize(x,y)
    --Position
    self.x = x or 0
    self.y = y or 0

    self.open = false

    self.quad = love.graphics.newQuad(0,16,16,32,entityImage:getWidth(),entityImage:getHeight())
end

function doorThru(self)
    player.inspecting = false
    player.interacted = false
    player.inputLocked = false

    player.snap = true
    
    player.x = self.data.gotoX*tileSize+0x1000
    player.y = self.data.gotoY*tileSize+0x1000

    self.open = false

    if self.data.gotoDir ~= 0 then
        player.facing = math.sign(self.data.gotoDir)
    end

    if self.data.cameraX and self.data.cameraY then
        camera.lockX = self.data.cameraX*tileSize+0x1000
        camera.lockY = self.data.cameraY*tileSize+0x1000
    else
        player:bringCamera()

        camera.lockX = nil
        camera.lockY = nil
    end
end

function door:update()
    if player then
        local diffX = math.abs(player.x-self.x)
        local diffY = math.abs(player.y-self.y)
        if diffX < 0x1000 and diffY < 0x1000 and player.grounded and player.interacted == false then
            if player.inspecting then
                player.xsp = 0
                player.ysp = 0
                
                player.interacted = true
                player.inputLocked = true

                self.open = true

                fadeDirection = self.data.fadeDir
                fadeReverse = false
                fadeFunction = doorThru
                fadeData = {self}
            end
        end
    end
end

function door:draw()
    love.graphics.setColor(1,1,1,1)

    self.quad:setViewport(self.open and 16 or 0,16,16,32,entityImage:getWidth(),entityImage:getHeight())
    love.graphics.draw(entityImage,self.quad,self.x*unitScale,self.y*unitScale,0,1,1,8,24)
end

return door