function justDisconnect()
    if client then
        if client:isConnected() then
            client:disconnectNow()
        end
        client = nil
    end

    goBackToTitle()
end

function initGame()
    userdat = {} --clear
    effects = {} --clear
    bullets = {} --clear
    player = nil

    currentMenu = nil

    --Randomize randomization using math.random and the current time (wow im a sucker)
    math.randomseed(love.timer.getTime()+math.random(0,100))
    math.random()
    math.randomseed(love.timer.getTime()+math.random(5,1000))

    loadLevelOrg(true)

    local spawn = level.spawns[math.random(1,#level.spawns)]

    player = classes["quote"]:new(tonumber(spawn[1])*tileSize+0x1000,tonumber(spawn[2])*tileSize+0x1000)
    player.facing = tonumber(spawn[3]) ~= 0 and math.sign(tonumber(spawn[3])) or math.random(0,1)*2-1
    player.spawned = true
    player.skin = currentSkin

    player.snap = true

    player:bringCamera()
end

function respawnQuote()
    loadLevelOrg(false)

    local spawn = level.spawns[math.random(1,#level.spawns)]

    player = classes["quote"]:new((spawn[1]*16+8)/unitScale,(spawn[2]*16+8)/unitScale)
    player.facing = spawn[3] ~= 0 and spawn[3] or math.random(0,1)*2-1
    player.spawned = false
    player.skin = currentSkin

    player.snap = true

    player:bringCamera()

    client:send("userupdate",{resetHp=true,username=_G.username,hp=player.hp,maxhp=player.maxhp,x=player.x,y=player.y,facing=player.facing,skin=customSkinImage and customSkinData or clientInfo.skin,animFrame=player.frame,frame=player.lastDrawnFrame,animation=animationName,weapon=player.weapon})
end

local function start(dat)
    dat = dat or {}
    currentMenu = "connecting"

    client = sock.newClient(dat[1] or serverInfo.ip, 12004)
    client:enableCompression()

    stopSong() --Stop whatever song is playing

    client:on("connect", function(data)
        print("connected to "..serverInfo.ip..":"..serverInfo.port)

        client:send("verCheck",{version=version,checksum=checksum})
        
        client:send("userInfo",{username=clientInfo.username,skin=customSkinImage and customSkinData or clientInfo.skin})
    end)

    client:on("disconnect", function(data)
        print("disconnect from "..serverInfo.ip..":"..serverInfo.port)

        if data then
            if data == 10 then
                quitWithError("Server shutdown.")
            elseif data == 20 then
                quitWithError("Server doesn't support V"..version)
            elseif data == 30 then
                quitWithError("Invalid checksum.")
            end
        else
            justDisconnect()
        end
    end)

    client:on("peerConnect", function(data)
        --Clear old data
        userdat[data] = nil
    end)

    client:on("peerDisconnect", function(data)
        if userdat[data] then
            userdat[data] = nil
        end
    end)

    client:on("myid",function(data)
        myId = data
    end)

    client:on("userupdate",function(data)
        userdat[data.id] = userdat[data.id] or {}

        userdat[data.id].lx = userdat[data.id].x or data.x
        userdat[data.id].ly = userdat[data.id].y or data.y

        if data.snap then
            userdat[data.id].lx = data.x
            userdat[data.id].ly = data.y
        end

        userdat[data.id].lt = love.timer.getTime()

        for i,v in pairs(data) do
            userdat[data.id][i] = v
        end

        if data.id == myId then
            player.spawned = true

            player.hp = data.hp
            player.maxhp = data.maxhp

            if player.hp > 0 then
                player.dead = false
            end
        end
    end)

    client:on("userInfo",function(data)
        userdat[data.id] = userdat[data.id] or {}

        userdat[data.id].username = data.username

        if data.id ~= myId then
            if type(data.skin) == "number" then
                userdat[data.id].skin = data.skin
            else
                userdat[data.id].skin = love.graphics.newImage(love.filesystem.newFileData(data.skin,"tempSkn"))
            end
        end
    end)

    client:on("bulletSpawn",function(data)
        data.endt = love.timer.getTime()+(data.aliveTime/60)

        table.insert(bullets,data)

        --Kill bullet if in wall
        bulletCollide(data,false)
    end)

    client:on("loadlevel",function(data)
        loadLevelFromData(unpack(data))

        initGame()
    end)

    client:on("destroyBullet",function(data)
        for i,v in pairs(bullets) do
            if v.id == data then
                bullets[i] = nil
            end
        end
    end)

    client:on("playerEvent",function(data)
        if data == "hurt" then
            player:damageBoost()
        elseif data == "die" then
            player:die()
        end
    end)

    client:connect()
    connectTime = love.timer.getTime()
end

local function update(dt)
    client:update()

    if client then --Client may be destroyed afterwards?
        if client:isConnected() and level and level.loaded then
            gameUpdate(dt)

            --Run client
            if love.timer.getTime()-clp > tickRate then
                clp = love.timer.getTime()

                if player then
                    local animationName = "null"

                    for v,i in pairs(player) do
                        if i == player.animation and v ~= "animation" then
                            animationName = v
                        end
                    end
                    
                    client:send("userupdate",{hp=player.hp,snap=player.snap,maxhp=player.maxhp,x=player.x,y=player.y,facing=player.facing,animFrame=player.frame,frame=player.lastDrawnFrame,animation=animationName,weapon=player.weapon})

                    player.snap = false
                end
            end
        elseif not client:isConnected() then
            if love.timer.getTime() >= connectTime + 5 then
                quitWithError("Connection timed out")
            end
        end
    end
end

return {update,start}