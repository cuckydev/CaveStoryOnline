inGlobalList = false

portCheck = nil

serverIp = nil

function closeServer()
    if server then
        for _,client in pairs(server:getClients()) do
            client:disconnectNow(10)
        end

        server:destroy()
        server = nil
    end
end

function datClone(t)
    local r = {}
    for i,v in pairs(t) do
        r[i] = v
    end
    return r
end

function phpEncode(tab)
    local ret = ""

    for i,v in pairs(tab) do
        ret = ret..(tostring(i).."="..tostring(v)).."&"
    end

    return string.sub(ret,1,-1)
end

function updateServerList(showMessage)
    local success1,result1 = apiclient("GET", "http://api.ipify.org/", "")

    if success1 then
        serverIp = result1

        local chk = string.gsub(serverInfo.name,"%s+", " ")

        if chk:len() > 0 and chk ~= " " then
            inGlobalList = true
        elseif showMessage then
            inGlobalList = false

            errorMessage = {"Server is private (not in global server list)",love.timer.getTime()}
        end
    else
        quitWithError("Not connected to the internet?")
    end
end

local lastPing = 0
local function start()
    server = sock.newServer("*", 12004, 64)
    server:enableCompression()
    
    userdat = {}
    bullets = {}

    currentMenu = "hosting"

    serverIp = nil

    lastPing = love.timer.getTime() - 25

    stopSong() --Stop whatever song is playing

    if portCheck and portCheck:isConnected() then
        portCheck:disconnectNow()
    end

    portCheck = nil

    --Now load the current level
    if loadLevel(serverLevels[serverInfo.gamemode][serverInfo.selectedLevel+1].path) and server then
        inGlobalList = false

        updateServerList(true)

        if server then
            server:on("connect", function(data, gclient)
                print("Client connected!")

                if data == 400 then
                    return
                end

                server:setSendMode("reliable")

                userdat[gclient:getIndex()] = {}
                userdat[gclient:getIndex()].hp = level.matchData.startingHealth
                userdat[gclient:getIndex()].maxhp = level.matchData.startingHealth

                server:sendToPeer(server:getPeerByIndex(gclient:getIndex()),"loadlevel",{level.name,level.rawpxm,level.types,level.pspData,level.tilesetDat,level.org,level.backgroundDat,level.entData})
                
                server:sendToPeer(server:getPeerByIndex(gclient:getIndex()),"myid",gclient:getIndex())
                server:sendToAllBut(gclient,"peerConnect",gclient:getIndex())

                local peer = server:getPeerByIndex(gclient:getIndex())
                for i,v in pairs(userdat) do
                    if v.id and v.username and v.skin then
                        server:sendToPeer(peer,"userInfo",{id=v.id,username=v.username,skin=v.skin})
                    end
                end
            end)

            server:on("verCheck", function(data,gclient)
                server:setSendMode("reliable")

                if data.version == nil or data.version ~= version or data.checksum == nil then
                    gclient:disconnect(20)
                elseif data.checksum ~= checksum then
                    gclient:disconnect(30)
                end
            end)

            server:on("disconnect", function(data, gclient)
                server:setSendMode("reliable")
                print("Client disconnected")

                if userdat[gclient:getIndex()] then
                    userdat[gclient:getIndex()] = nil
                end

                server:sendToAllBut(gclient,"peerDisconnect",gclient:getIndex())
            end)

            server:on("userupdate",function(data, gclient)
                server:setSendMode("unreliable")

                if data.version or data.checksum then
                    gclient:disconnect(20)
                    return
                end
                
                if userdat[gclient:getIndex()] and userdat[gclient:getIndex()].username and userdat[gclient:getIndex()].skin then
                    data.id = gclient:getIndex()
                    
                    if data.resetHp then
                        userdat[gclient:getIndex()].hp = level.matchData.startingHealth
                        userdat[gclient:getIndex()].maxhp = level.matchData.startingHealth

                        data.resetHp = false
                    end

                    data.kills = userdat[gclient:getIndex()].kills or 0
                    data.deaths = userdat[gclient:getIndex()].deaths or 0

                    data.hp = userdat[gclient:getIndex()].hp or level.matchData.startingHealth
                    data.maxhp = userdat[gclient:getIndex()].maxhp or level.matchData.startingHealth

                    data.invulnerable = userdat[gclient:getIndex()].invulnerable or 0

                    local send = datClone(data)
                    --REDUNDANT
                    send.username = nil
                    send.skin = nil

                    server:sendToAll("userupdate",send)

                    userdat[gclient:getIndex()].client = gclient
                    userdat[gclient:getIndex()] = userdat[gclient:getIndex()] or {}

                    for i,v in pairs(data) do
                        userdat[gclient:getIndex()][i] = v
                    end
                end
            end)

            server:on("userInfo",function(data, gclient)
                server:setSendMode("reliable")
                data.id = gclient:getIndex()
                userdat[gclient:getIndex()].username = data.username
                userdat[gclient:getIndex()].skin = data.skin

                server:sendToAll("userInfo",data)
            end)

            server:on("bulletSpawn",function(data, gclient)
                server:setSendMode("reliable")
                local s,e = pcall(function() -- below can easily crash if messed with
                    if userdat[gclient:getIndex()] and userdat[gclient:getIndex()].x and userdat[gclient:getIndex()].y and userdat[gclient:getIndex()].hp > 0 then
                        data.x = userdat[gclient:getIndex()].x+data.xoff+data.xsp
                        data.y = userdat[gclient:getIndex()].y+data.yoff+data.ysp
                        data.lastx = data.x
                        data.lasty = data.y

                        data.id = gclient:getIndex()*1000+#bullets --this is basically impossible to break

                        server:sendToAll("bulletSpawn",data)

                        data.client = gclient
                        data.endt = love.timer.getTime()+((data.aliveTime-1)/60)

                        table.insert(bullets,data)
                        bulletCollide(data,true)
                    end
                end)
            end)
        end
    end
end

local function update(dt)
    server:update()

    if server then --Server dies?
        for i,bullet in pairs(bullets) do
            if bullet.endt > love.timer.getTime() then
                bullet.x = bullet.x + dt * (bullet.xsp*60)
                bullet.y = bullet.y + dt * (bullet.ysp*60)

                bulletCollide(bullet,true)
            else
                bullets[i] = nil
            end
        end

        if portCheck then
            portCheck:update()
        end

        if love.timer.getTime() - lastPing > 30 and inGlobalList then
            lastPing = love.timer.getTime()
            
            local title = serverInfo.name
            local dat = phpEncode({
                ["title"] = title,
                ["description"] = "Gamemode: FFA"..string.char(10).."Players: "..tostring(server:getClientCount()),
                ["version"] = version,
            })

            local success,result = apiclient("POST", "68.45.103.237/servers", dat) --Add server to server list

            if success == false then
                errorMessage = {"Failed to add to global server list",love.timer.getTime()}
            end
        end
    end
end

return {update,start}