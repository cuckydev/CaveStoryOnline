do --Load all levels
    local loadGamemodes = {"ffa"}

    local function loadLevelsFrom(from)
        for i=1,#loadGamemodes do
            local gamemodeName = loadGamemodes[i]

            local LreadDir = from..gamemodeName.."/"
            local files = love.filesystem.getDirectoryItems(LreadDir)

            for _, filename in ipairs(files) do
                local readDir = LreadDir..filename.."/"
                local thumbPath = readDir..filename.."Thumb.png"

                local thumbImage = nil
                if love.filesystem.getInfo(thumbPath) then
                    thumbImage = love.graphics.newImage(thumbPath)
                end
                    
                serverLevels[gamemodeName][#serverLevels[gamemodeName]+1] = {name=filename,path = readDir..filename,thumbnail = thumbImage}
            end
        end
    end

    if love.filesystem.isFused() then --Running .exe?
        local dir = love.filesystem.getSourceBaseDirectory()
        local success = love.filesystem.mount(dir, "source")

        if success then
            loadLevelsFrom("source/stages/")
        end
    else
        loadLevelsFrom("assets/stages/")
    end
end

local windM = {1,0,0,1,-1,0,0,-1}
function drawLevel(foreground)
    love.graphics.setColor(1,1,1,1)

    --Get camera boundaries
    local lx = math.floor(camera.x/tileSize)
    local ly = math.floor(camera.y/tileSize)
    local ex = math.floor((camera.x+view.width/unitScale)/tileSize)+1
    local ey = math.floor((camera.y+view.height/unitScale)/tileSize)+1

    --Iterate through every tile in these boundaries
    for y=math.max(1,ly+1),math.min(ey+1,#level.tiles) do
        for x=math.max(1,lx+1),math.min(ex+1,#level.tiles[y]) do
            local v = level.tiles[y][x]
            local t = level.types[v]

            --If statement to check if tile should be drawn (at least right now)
            if t > 0x00 and ((foreground and t >= 0x40) or ((foreground == false) and t < 0x20)) then
                local tx = (v-1)%(level.tileset:getWidth()/16)
                local ty = math.floor((v-1)/(level.tileset:getWidth()/16))

                --Draw tile
                level.quad:setViewport(tx*16,ty*16,16,16,level.tileset:getWidth(),level.tileset:getHeight())
                love.graphics.draw(level.tileset,level.quad,(x-1)*16,(y-1)*16)

                if (t >= 0x80 and t%0x10 <= 0x03) then
                    local d = t%0x10

                    local wX = (windM[(d*2)+1]*gameTime*2)%16
                    local wY = (windM[(d*2)+2]*gameTime*2)%16

                    level.quad:setViewport(wX,wY,16,16,16,16)
                    love.graphics.draw(windImage,level.quad,(x-1)*16,(y-1)*16)
                end
            end
        end
    end
end

function loadLevelFromData(name,pxmData,pxaData,spawnData,tilesetDat,orgRef,backgroundDat,entData) --Loads level from data sent via the server
    --Clear current level
    level = {width=0,height=0,name=name,loaded=true,tiles={},types={},spawns={},org=orgRef,tiles=nil,quad=nil}
    objects = {}

    collectgarbage()

    --Load tileset
    level.tileset = love.graphics.newImage(love.filesystem.newFileData(tilesetDat,"tempTsD")) --Creates a temp file of the tileset and creates an image out of that
    level.quad = love.graphics.newQuad(0,0,16,16,level.tileset:getWidth(),level.tileset:getHeight())

    --Load background
    local backImage = love.graphics.newImage(love.filesystem.newFileData(backgroundDat,"tempBgD")) --Creates a temp file of the background and creates an image out of that
    backImage:setWrap("repeat","repeat")
    
    --Set background to use created background image and new quad to go along with it
    currentBackground = {backImage,love.graphics.newQuad(0,0,426+backImage:getWidth(),240+backImage:getHeight(),backImage:getWidth(),backImage:getHeight())}

    --Load pxa tiletype data
    level.types = pxaData

    --Set level width and height
    level.width = pxmData[5] + pxmData[6] * 0x100
    level.height = pxmData[7] + pxmData[8] * 0x100

    --Set spawns
    local spawns = stringSplit(spawnData,";")

    for i=1,#spawns do
        local spawnData = stringSplit(spawns[i],":")

        level.spawns[i] = spawnData
    end

    --Parse pxm data
    for i=9,#pxmData do
        local ti = i-9

        local x = ti%level.width
        local y = math.floor(ti/level.width)

        if not level.tiles[y+1] then
            level.tiles[y+1] = {}
        end

        level.tiles[y+1][x+1] = pxmData[i]+1
    end

    --Parse entity data
    objects = {}

    local pend = json.decode(entData)

    for i,v in pairs(pend) do
        if v.type and v.x and v.y and v.type ~= "quote" and classes[v.type] and v.data then
            local s,e = pcall(function()
                local robj = classes[v.type]:new(v.x*tileSize+tileSize/2,v.y*tileSize+tileSize/2)
                robj.data = v.data

                if robj then
                    objects[tonumber(i)] = robj
                end
            end)
        end
    end
end

function loadLevel(path)
    --Clear current level and set variables for new one
    local spl = stringSplit(path,"/")

    objects = {}
    level = {width=0,name=spl[#spl],loaded=true,height=0,tiles={},types={},spawns={},tiles=nil,quad=nil,org=lorg,matchData=nil}

    collectgarbage()

    --Load pxa tiletype data
    if not love.filesystem.getInfo(path..".pxm") then
        quitWithError("No map (.pxm) data found")
        return false
    end

    local pxmData = loadBinary(path..".pxm")
    level.rawpxm = pxmData

    --Load tileset
    if not love.filesystem.getInfo(path..".png") then
        quitWithError("No tileset found")
        return false
    end

    level.tileset = love.graphics.newImage(path..".png")
    level.tilesetDat = love.filesystem.read(path..".png")

    level.quad = love.graphics.newQuad(0,0,16,16,level.tileset:getWidth(),level.tileset:getHeight())

    --Load background
    if not love.filesystem.getInfo(path.."BG.png") then
        quitWithError("No background found")
        return false
    end

    level.backgroundImg = love.graphics.newImage(path.."BG.png")
    level.backgroundDat = love.filesystem.read(path.."BG.png")

    if not love.filesystem.getInfo(path..".pxa") then
        quitWithError("No attribute (.pxa) data found")
        return false
    end

    level.types = loadBinary(path..".pxa")

    --Set level width and height
    level.width = pxmData[5] + pxmData[6] * 0x100
    level.height = pxmData[7] + pxmData[8] * 0x100

    --Parse pxm data
    for i=9,#pxmData do
        local ti = i-9

        local x = ti%level.width
        local y = math.floor(ti/level.width)

        if not level.tiles[y+1] then
            level.tiles[y+1] = {}
        end

        level.tiles[y+1][x+1] = pxmData[i]+1
    end

    --Load org data (clients will hear nothing if invalid)
    local lorg = love.filesystem.read(path..".org") or ""
    level.org = lorg

    if not level.org then
        quitWithError("No .org found")
        return false
    end

    --Load spawns
    local pspData = love.filesystem.read(path..".psp")
    level.pspData = pspData

    if not level.pspData then
        quitWithError("No spawn (.psp) data found")
        return false
    end

    local spawns = stringSplit(pspData,";")

    for i=1,#spawns do
        local spawnData = stringSplit(spawns[i],":")

        level.spawns[i] = spawnData
    end

    --load entities
    level.entData = love.filesystem.read(path..".ent")

    if not level.entData then
        quitWithError("No entity (.ent) data found")
        return false
    end

    --load match data
    --Load spawns
    local matchData = love.filesystem.read(path..".mtd")

    if not matchData then
        quitWithError("No match data (.mtd) found")
        return false
    end

    level.matchData = json.decode(matchData)

    return true
end