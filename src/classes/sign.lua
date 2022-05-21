sign = class("sign")

function sign:initialize(x,y)
    --Position
    self.x = x or 0
    self.y = y or 0

    self.quad = love.graphics.newQuad(0,0,16,16,entityImage:getWidth(),entityImage:getHeight())
end

function sign:update()
end

function sign:draw()
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(entityImage,self.quad,self.x*unitScale,self.y*unitScale,0,1,1,8,8)

    --Draw message
    if math.abs(player.x-self.x) <= 0x2000 and math.abs(player.y-self.y) <= 0x2000 then
        readSign = self
    end
end

return sign