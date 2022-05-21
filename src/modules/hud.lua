function drawHud()
    local hiw,hih = hudImage:getWidth(),hudImage:getHeight() --Temporary variables

    love.graphics.origin()

    love.graphics.setColor(1,1,1,1)
    love.graphics.setFont(numberFont)

    --Current winner of free-for-all
    local participants = {}
    for i,v in pairs(userdat) do
        if v.username and v.kills and v.deaths then
            table.insert(participants,{(v.kills-v.deaths)*(v.kills^v.deaths),v.username.."("..v.kills.."/"..v.deaths..")"})
        end
    end

    table.sort(participants,function(a,b)return a[1]>b[1] end)

    if #participants > 0 then
        drawText("#1: "..participants[1][2],view.width-8,8,1,1,1,false,true)
        if #participants > 1 then
            drawText("#2: "..participants[2][2],view.width-8,20,1,1,1,false,true)

            if #participants > 2 then
                drawText("#3: "..participants[3][2],view.width-8,32,1,1,1,false,true)
            end
        end
    end

    --Current weapon info
    local amountOfWeapons = 0

    love.graphics.origin()
    love.graphics.translate(view.compactHud and 72 or 16, view.compactHud and 8 or 16)

    if player then
        for _,v in pairs(player.weapons) do
            amountOfWeapons = amountOfWeapons + 1
        end

        if amountOfWeapons > 0 then
            if player.weapon > 0 then
                hudQuad:setViewport(player.weapon*16,0,16,16,armsHudImage:getWidth(),armsHudImage:getHeight())
                love.graphics.draw(armsHudImage,hudQuad,0,0)
            end

            if amountOfWeapons > 1 then
                local ind = player.weapon
                local drawn = 0

                while true do
                    ind = ind + 1

                    if ind > amountOfWeapons + 1 then
                        ind = 1
                    end

                    if ind == player.weapon then
                        break
                    end

                    if player.weapons[ind] then
                        hudQuad:setViewport(ind*16,0,16,16,armsHudImage:getWidth(),armsHudImage:getHeight())
                        love.graphics.draw(armsHudImage,hudQuad,64 + (drawn*16),0)

                        drawn = drawn + 1
                    end
                end
            end
        end
    else
        hudQuad:setViewport(2*16,0,16,16,armsHudImage:getWidth(),armsHudImage:getHeight())
        love.graphics.draw(armsHudImage,hudQuad,0,0)
    end

    --Ammo
    local ammo = "--"
    local maxammo = "--"

    if player and player.weapons[player.weapon] then
        if player.weapons[player.weapon].maxammo > 0 then
            ammo = tostring(player.weapons[player.weapon].ammo)
            maxammo = tostring(player.weapons[player.weapon].maxammo)
        end
    end

    love.graphics.printf(ammo,-16,0,80,"right")
    love.graphics.print("/",32,8)
    love.graphics.printf(maxammo,-16,8,80,"right")

    --Level label
    love.graphics.origin()
    love.graphics.translate(view.compactHud and 8 or 16, view.compactHud and 8 or 32)

    hudQuad:setViewport(0,40,24,8,hiw,hih)
    love.graphics.draw(hudImage,hudQuad,0,0)

    --Level container
    hudQuad:setViewport(24,40,1,8,hiw,hih)
    love.graphics.draw(hudImage,hudQuad,24,0)

    hudQuad:setViewport(25,40,1,8,hiw,hih)
    love.graphics.draw(hudImage,hudQuad,25,0,0,38,1)

    hudQuad:setViewport(26,40,1,8,hiw,hih)
    love.graphics.draw(hudImage,hudQuad,63,0)

    --Draw level (number)
    local currentLevel = player and (player.weapons[player.weapon] and player.weapons[player.weapon].level or 0) or 1
    
    love.graphics.printf(tostring(currentLevel),-8,0,32,"right")

    --HP label
    hudQuad:setViewport(0,32,24,8,hiw,hih)
    love.graphics.draw(hudImage,hudQuad,0,8)

    --HP container
    hudQuad:setViewport(24,32,1,8,hiw,hih)
    love.graphics.draw(hudImage,hudQuad,24,8,0,38,1)

    hudQuad:setViewport(25,32,2,8,hiw,hih)
    love.graphics.draw(hudImage,hudQuad,62,8)

    --Draw amount of health (bar)
    local hp = player and player.hp or 3
    local maxhp = player and player.maxhp or 3

    hudQuad:setViewport(27,32,1,8,hiw,hih)
    love.graphics.draw(hudImage,hudQuad,24,8,0,(hp/maxhp)*39,1)

    --Draw amount of health (number)
    love.graphics.printf(tostring(hp),-8,8,32,"right")

    --Draw current kdr
    love.graphics.origin()
    for i,v in pairs(userdat) do
        if v.id == myId then
            drawText(userdat[myId].kills.."/"..userdat[myId].deaths.." KDR",view.width-8,view.height-16,1,1,1,false,true)
        end
    end
end