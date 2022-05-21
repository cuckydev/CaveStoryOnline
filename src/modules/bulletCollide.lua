return function(bullet,isServer)
    local left = math.min(bullet.x,bullet.lastx)-bullet.xsp
    local right = math.max(bullet.x,bullet.lastx)+bullet.xsp

    local up = math.min(bullet.y,bullet.lasty)-bullet.ysp
    local down = math.max(bullet.y,bullet.lasty)+bullet.ysp
    local checkRectangle = {x=left,y=up,w=right-left,h=down-up}

    local collideTiles = getTilesInRectangle(checkRectangle)

    for i=#collideTiles,1,-1 do
        local type = collideTiles[i].type

        if not (type == 0x05 or type == 0x41 or type == 0x43) then
            table.remove(collideTiles,i)
        end
    end

    if #collideTiles > 0 then
        if isServer then
            server:setSendMode("reliable")
            server:sendToAll("destroyBullet",bullet.id)
        end

        for i,blt in pairs(bullets) do
            if blt == bullet then
                bullets[i] = nil
                return
            end
        end
    elseif isServer then --Pvp
        for _,hit in pairs(userdat) do
            if bullet and bullet.x and bullet.y and hit.id ~= bullet.client:getIndex() then
                if hit and hit.x and hit.y and rectIntersect(checkRectangle,{x=hit.x-0x1000,y=hit.y-0x1000,w=0x2000,h=0x2000}) then
                    if hit.hp > 0 and love.timer.getTime() >= hit.invulnerable then
                        hit.hp = hit.hp - 1

                        if hit.hp > 0 then
                            hit.invulnerable = love.timer.getTime() + 1
                            server:setSendMode("reliable")
                            server:sendToPeer(server:getPeerByIndex(hit.id),"playerEvent","hurt")
                        else
                            if bullet.client and userdat[bullet.client:getIndex()] then
                                userdat[bullet.client:getIndex()].kills = userdat[bullet.client:getIndex()].kills + 1
                            end

                            userdat[hit.id].deaths = userdat[hit.id].deaths + 1
                            server:setSendMode("reliable")
                            server:sendToPeer(server:getPeerByIndex(hit.id),"playerEvent","die")
                        end

                        for i,blt in pairs(bullets) do
                            if blt == bullet then
                                server:setSendMode("reliable")
                                server:sendToAll("destroyBullet",bullet.id)
                                bullets[i] = nil
                                return
                            end
                        end
                    end
                end
            end
        end
    end
end