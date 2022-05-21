readSign = nil

local function update(dt)
    --Update objects, effects, and bullets
    for _,object in pairs(objects) do
        object:update()
    end

    if player then
        player:update()
    end

    for _,effect in pairs(effects) do
        effect:update()
    end

    for i,bullet in pairs(bullets) do
        if bullet.endt > love.timer.getTime() then
            bullet.lastx = bullet.x
            bullet.lasty = bullet.y
            bullet.x = bullet.x + dt * (bullet.xsp*60)
            bullet.y = bullet.y + dt * (bullet.ysp*60)

            bulletCollide(bullet,false)
        else
            bullets[i] = nil
        end
    end

    --Update camera
    local animationName = "null"

    if player then
        if camera.lockX and camera.lockY then
            local gx = camera.lockX-(view.width/2)/unitScale
            local gy = camera.lockY-(view.height/2)/unitScale

            camera.x = gx
            camera.y = gy
            camera.tgt_x = gx
            camera.tgt_y = gy
            camera.xVel = 0
            camera.yVel = 0
        else
            camera.tgt_x = player.x+player.camOffX
            camera.tgt_y = player.y+player.camOffY

            local xspd = (camera.tgt_x - (view.width/2)/unitScale - camera.x)
            local yspd = (camera.tgt_y - (view.height/2)/unitScale - camera.y)

            camera.xVel = math.round(xspd / camera.speed)
            camera.yVel = math.round(yspd / camera.speed)

            camera.x = camera.x + camera.xVel
            camera.y = camera.y + camera.yVel
        end

        camera.x = math.max(math.min(camera.x,level.width*tileSize-0x1000-(view.width/unitScale)),0x1000)
        camera.y = math.max(math.min(camera.y,level.height*tileSize-0x1000-(view.height/unitScale)),0x1000)
    end
end

local function draw()
    love.graphics.setBackgroundColor(0,0,0,1) --Transparency is black ;)

    love.graphics.translate(-math.round(camera.x*unitScale),-math.round(camera.y*unitScale)) --Move everything to move with the camera

    local backgroundX = (math.round(camera.x*unitScale*.5) % currentBackground[1]:getWidth())
    local backgroundY = (math.round(camera.y*unitScale*.5) % currentBackground[1]:getHeight())

    love.graphics.draw(currentBackground[1],currentBackground[2],camera.x*unitScale-backgroundX,camera.y*unitScale-backgroundY)

    drawLevel(false) --Background tiles

    --Draw objects, then effects
    readSign = nil
    
    for _,object in pairs(objects) do
        object:draw()
    end

    --Draw bullets
    for _,bullet in pairs(bullets) do
        otherPlayerQuad:setViewport((bullet.level-1)*16,(bullet.weapon-1)*16,16,16,bulletImage:getWidth(),bulletImage:getHeight())
        love.graphics.draw(bulletImage,otherPlayerQuad,bullet.x*unitScale,bullet.y*unitScale,bullet.angle,1,1,8,8)--line(bullet.x-bullet.xsp/2,bullet.y-bullet.ysp/2,bullet.x+bullet.xsp/2,bullet.y+bullet.ysp/2)
    end

    --Draw other players
    for i,v in pairs(userdat) do
        love.graphics.setColor(1,1,1,1)

        if v.id ~= myId and v.username and v.skin and v.weapon and v.frame and v.animFrame and v.weapon and v.animation then
            local lx = math.lerp(v.lx,v.x,math.min((love.timer.getTime()-v.lt)/tickRate,1))
            local ly = math.lerp(v.ly,v.y,math.min((love.timer.getTime()-v.lt)/tickRate,1))

            if v.weapon > 0 then
                local drawFrame = math.floor(v.animFrame)

                local offsetLookup = weapons[v.weapon].animationOffsets[v.animation]

                if offsetLookup then
                    local gunXOffset = offsetLookup[(drawFrame)*2+1]
                    local gunYOffset = offsetLookup[(drawFrame)*2+2]
            
                    local gunFrame = string.find(v.animation,"Up") and 1 or string.find(v.animation,"Down") and 2 or 0
                    
                    otherPlayerQuad:setViewport((v.weapon)*24,gunFrame*16,24,16,armsImage:getWidth(),armsImage:getHeight())
                    love.graphics.draw(armsImage,otherPlayerQuad,math.round(lx*unitScale) + (gunXOffset * v.facing),math.round(ly*unitScale)+gunYOffset,0,v.facing,1,12,8)
                end
            end

            if type(v.skin) == "number" then
                otherPlayerQuad:setViewport(v.frame*16,v.skin*16,16,16,myChar:getWidth(),myChar:getHeight())
                love.graphics.draw(myChar,otherPlayerQuad,math.round(lx*unitScale),math.round(ly*unitScale),0,v.facing,1,8,8)
            else
                otherPlayerQuad:setViewport(v.frame*16,0,16,16,128,16)
                love.graphics.draw(v.skin,otherPlayerQuad,math.round(lx*unitScale),math.round(ly*unitScale),0,v.facing,1,8,8)
            end
        end
    end

    if player then
        player:draw()
    end

    for _,effect in pairs(effects) do
        effect:draw()
    end

    --Foreground tiles
    drawLevel(true)

    --Draw usernames (and chat, soon enough)
    for i,v in pairs(userdat) do
        if v.id ~= myId and v.username and v.skin and v.weapon and v.frame then
            local lx = math.lerp(v.lx,v.x,math.min((love.timer.getTime()-v.lt)/tickRate,1))
            local ly = math.lerp(v.ly,v.y,math.min((love.timer.getTime()-v.lt)/tickRate,1))

            local drawKDR = true

            --Draw actual username
            do
                local usernameText = v.username or tostring(i)

                love.graphics.setColor(0,0,0,.5)
                love.graphics.rectangle("fill",math.round(lx*unitScale)-(string.len(usernameText)*3)-4,math.round(ly*unitScale)-24,string.len(usernameText)*6+8,11,4,4)

                drawText(usernameText,math.round(lx*unitScale)+1,math.round(ly*unitScale)-24,1,1,1,true)
            end

            --Draw KDR
            if drawKDR and v.kills and v.deaths then
                local kdrText = tostring(v.kills).."/"..tostring(v.deaths).." KDR"

                love.graphics.setColor(0,0,0,.5)
                love.graphics.rectangle("fill",math.round(lx*unitScale)-(string.len(kdrText)*3)-4,math.round(ly*unitScale)-35,string.len(kdrText)*6+8,11,4,4)

                drawText(kdrText,math.round(lx*unitScale)+1,math.round(ly*unitScale)-35,1,1,1,true)
            end

            --Draw health bar
            if v and v.hp and v.maxhp and v.maxhp > 0 then
                local wh = v.hp/v.maxhp

                love.graphics.setColor(0,0,0,1)
                love.graphics.rectangle("fill",math.round(lx*unitScale)-16,math.round(ly*unitScale)-12,32,2)
                love.graphics.setColor(1,1,1,1)
                love.graphics.rectangle("fill",math.round(lx*unitScale)-16,math.round(ly*unitScale)-12,32*wh,2)
            end
        end
    end

    --Draw sign text
    if readSign then
        love.graphics.setColor(0,0,0,.5)
        love.graphics.rectangle("fill",math.round(readSign.x*unitScale)-(string.len(readSign.data)*3)-4,math.round(readSign.y*unitScale)-24,string.len(readSign.data)*6+8,11,4,4)

        drawText(readSign.data,math.round(readSign.x*unitScale)+1,math.round(readSign.y*unitScale)-24,1,1,1,true)
    end

    for i=1,#rects do
        love.graphics.setColor(i*11.131%1,i-math.pi*14.45%1,i^4.4124%1,0.75)
        love.graphics.rectangle(unpack(rects[i]))
    end

    rects = {}

    drawHud()
end

return {update,draw}