--Parallax shader
local parallaxShader = love.graphics.newShader(love.filesystem.read("states/titleParallax.glsl"))

--Menu variables
local typing = false
local skinSelect = 0

local lastLevelThumbnail = nil

local levelThumbnailDX = 0
local levelThumbnailDY = 0

local levelThumbnailX = 0
local levelThumbnailY = 0

local levelThumbnailXsp = 1
local levelThumbnailYsp = 0.4

local menuScroll = 0

local menuTime = 0

local stars = {}
starQuad = love.graphics.newQuad(0,0,0,0,0,0)

function generateStar(x)
    table.insert(stars,{x=x,y=math.random(0,128),id=math.random(0,2)})
end

for i=-2,428,24 do
    generateStar(i)
end

--Some global menu functions
menuFunctions = {}

menuFunctions.getWidth = function() return view.width end
menuFunctions.getWidthDiv2 = function() return view.width/2 end

menuFunctions.getHeight = function() return view.height end
menuFunctions.getHeightDiv2 = function() return view.height/2 end

menuFunctions.getJoinText = function()
    local chk = string.gsub(clientInfo.username,"%s+", " ")
    return (serverInfo.ip == "" and "Please enter an IP") or ((string.len(chk) < 4 and "Username too short") or (string.len(chk) > 18 and "Username too long")) or "Join"
end

--Function to go to the title screen and display an error message
function quitWithError(message)
    justDisconnect()

    if server then
        server:destroy()
        server = nil
    end
    
    errorMessage = {message,love.timer.getTime()}
end

--Function for going back to the title screen
function goBackToTitle()
    loadSong("title")
    currentMenu = "title"

    menuScroll = 0

    currentOption = 0
end

--Play the selection/blip sound
function doBlip()
    sounds["blip"]:stop()
    sounds["blip"]:play()
end

function doSelect()
    sounds["select"]:stop()
    sounds["select"]:play()
end

function tableClone(t)
    local ret = {}

    for i,v in pairs(t) do
        ret[i] = v
    end

    return ret
end

--Skin Dropping
local expectedPixels = 64

function inspectCustomSkin(imgDat)
    --Inspect image
    if imgDat:getWidth() ~= 128 or imgDat:getHeight() ~= 16 then
        errorMessage = {"Dropped skin isn't 128x16",love.timer.getTime()}
        return false
    end

    for i=1,8 do
        local opaquePixels = 0
        local sx = (i-1)*16

        for x=sx,sx+15 do
            for y=0,imgDat:getHeight()-1 do
                local r,g,b,a = imgDat:getPixel(x,y)

                if a >= 0.75 then
                    opaquePixels = opaquePixels + 1
                end
            end
        end

        if opaquePixels < expectedPixels then
            errorMessage = {"Skin too transparent",love.timer.getTime()}
            return false
        end
    end

    return true
end

function love.filedropped(file)
    if client == nil and server == nil and currentMenu and string.lower(string.sub(file:getFilename(),-4)) == ".png" then
        file:open("r")
        local imgDat = love.image.newImageData(file)

        if inspectCustomSkin(imgDat) then
            imgDat:encode("png","customSkin.png")
            
            customSkinData = love.filesystem.read("customSkin.png")
            customSkinImage = love.graphics.newImage(imgDat)

            errorMessage = {"Custom Skin set!",love.timer.getTime()}
        end

        file:close()
    end
end

--Update event
local baseJoinMenu = {
    [1] = {"IP","set",{serverInfo,"string","ip"}},
    [2] = {menuFunctions.getJoinText,"join",{}},
}

local function update(dt)
    menuTime = menuTime + dt

    --Animate stars
    for i,star in pairs(stars) do
        star.x = star.x - 15*dt

        if star.x < -2 then
            stars[i] = nil
            generateStar(star.x + 432)
        end
    end

    if menus[currentMenu] and currentMenu ~= "connecting" and currentMenu ~= "hosting" then
        --Menu selection
        local largestOpt = 0

        for i,v in pairs(menus[currentMenu].options) do
            largestOpt = math.max(largestOpt,i)
        end

        local wasTyping = typing

        --Cancel out of text box
        if (pressedKeys["return"] or pressedKeys["escape"]) and typing then
            typing = false
            doSelect()
        end

        --Actually change the selection
        if typing == false then
            local lco = currentOption

            if bindPressed("up") then
                for i=currentOption-1,0,-1 do
                    if menus[currentMenu].options[i+1] then
                        currentOption = i
                        break
                    end
                end
            elseif bindPressed("down") then
                for i=currentOption+1,largestOpt do
                    if menus[currentMenu].options[i+1] then
                        currentOption = i
                        break
                    end
                end
            end

            if lco ~= currentOption then
                doBlip()
            end

            --When used, what does the button do
            if (bindPressed("jump") or (pressedKeys["return"] and wasTyping == false)) and menus[currentMenu].options[currentOption+1] then
                local selected = menus[currentMenu].options[currentOption+1]

                local action = selected[2]
                local dat = selected[3]

                local playSelect = false

                if action == "goto" then
                    currentMenu = dat
                    menuScroll = 0
                    loadSong("access")

                    if dat == "join" then
                        menus["join"].options = tableClone(baseJoinMenu)

                        local success,result = apiclient("GET", "http://api.cave.cf/servers", "") --Add server to server list

                        if success and result.servers then
                            menus["join"].render[4] = nil

                            local i = 5
                            for _,v in pairs(result.servers) do
                                if v.version == version then
                                    local text = v.title
                                    menus["join"].options[i] = {text,"joinalt",{v.host,v.description}}
                                    i = i + 1
                                end
                            end
                        else
                            menus["join"].render[4] = {type = "text", x = menuFunctions.getWidthDiv2, y = 112, data = "Failed to fetch any servers", arg = {1,1,1,true}}
                        end
                    end

                    currentOption = 0

                    skinSelect = 0
                    skinGoal = 0

                    playSelect = true
                elseif action == "set" then
                    if dat[2] == "bool" then
                        dat[1][dat[3]] = not dat[1][dat[3]]

                        if dat[4] then
                            (dat[4])()
                        end

                        playSelect = true
                    elseif dat[2] == "string" then
                        typing = true

                        if dat[4] and type(dat[4]) == "function" then
                            (dat[4])()
                        end

                        playSelect = true
                    end
                elseif action == "join" then
                    local chk = string.gsub(clientInfo.username,"%s+", " ")
                    local fail = (serverInfo.ip == "" and "Please enter an IP") or ((string.len(chk) < 4 and "Username too short") or (string.len(chk) > 18 and "Username too long")) or false

                    if fail then
                        quitWithError(fail)
                    else
                        startClient(dat)
                        playSelect = true
                    end
                elseif action == "joinalt" then
                    local chk = string.gsub(clientInfo.username,"%s+", " ")
                    local fail = ((string.len(chk) < 4 and "Username too short") or (string.len(chk) > 18 and "Username too long")) or false

                    if fail then
                        quitWithError(fail)
                    else
                        startClient(dat)
                        playSelect = true
                    end
                elseif action == "host" then
                    if not serverLevels[serverInfo.gamemode][serverInfo.selectedLevel+1] then
                        quitWithError("No level selected.")
                        return
                    end

                    startServer()
                    playSelect = true
                end

                if playSelect then
                    doSelect()
                end
            end

            --Fire button sends you back to the title screen
            if (bindPressed("fire") or pressedKeys["escape"]) and typing == false and currentMenu ~= "title" then
                goBackToTitle()
            end
        end

        --Typing
        if typing and wasTyping then --Was typing fixes Z adding onto textbox when initiated
            local selected = menus[currentMenu].options[currentOption+1]

            local action = selected[2]
            local dat = selected[3]

            dat[1][dat[3]] = dat[1][dat[3]]..typeInput

            if pressedKeys["backspace"] then
                local byteoffset = utf8.offset(dat[1][dat[3]], -1)

                if byteoffset then
                    dat[1][dat[3]] = string.sub(dat[1][dat[3]], 1, byteoffset - 1)
                end
            end
        end

        --Left and right buttons for stuff like numbers and skin selection
        local lrD = (bindPressed("right") and 1 or 0) - (bindPressed("left") and 1 or 0)

        if menus[currentMenu].options[currentOption+1] and lrD ~= 0 then
            local selected = menus[currentMenu].options[currentOption+1]

            local action = selected[2]
            local dat = selected[3]

            if action == "set" then
                if dat[2] == "number" then
                    local lsdt = dat[1][dat[3]]

                    dat[1][dat[3]] = math.max(math.min(dat[1][dat[3]]+lrD,dat[6]),dat[5])

                    if dat[1][dat[3]] ~= lsdt then
                        if dat[4] then
                            (dat[4])()
                        end

                        doSelect()
                    end
                end
            elseif action == "skin" then
                if customSkinImage then
                    love.filesystem.remove("customSkin.png")
                    customSkinImage = nil
                    clientInfo.skin = 0

                    skinSelect = 0
                else
                    clientInfo.skin = (clientInfo.skin + lrD) % #skins

                    skinSelect = skinSelect + lrD
                end

                doBlip()
            elseif action == "level" then
                serverInfo.selectedLevel = (serverInfo.selectedLevel + lrD) % #serverLevels[serverInfo.gamemode]

                doSelect()
            end
        end
    end

    --Scrolling
    local baseY = menus[currentMenu].optionsOff or view.height/2
    local cursorY = baseY+6+(currentOption*16)

    local highest = 0

    for i,v in pairs(menus[currentMenu].options) do
        highest = math.max(highest,i-1)
    end

    local max = baseY+32+(highest*16)

    menuScroll = math.lerp(menuScroll,math.max(0,math.min(max-view.height, cursorY - view.height / 2)),.1)

    --Animate level thumbnail
    if serverLevels[serverInfo.gamemode][serverInfo.selectedLevel+1] then
        local currentLevelThumbnail = serverLevels[serverInfo.gamemode][serverInfo.selectedLevel+1].thumbnail

        if currentLevelThumbnail then
            if currentLevelThumbnail ~= lastLevelThumbnail then
                levelThumbnailX = currentLevelThumbnail:getWidth()/2-(view.width/2)
                levelThumbnailDX = levelThumbnailX

                levelThumbnailY = currentLevelThumbnail:getHeight()/2-(view.height/2)
                levelThumbnailDY = levelThumbnailY

                lastLevelThumbnail = currentLevelThumbnail
            end

            levelThumbnailX = levelThumbnailX + levelThumbnailXsp
            levelThumbnailY = levelThumbnailY + levelThumbnailYsp

            if levelThumbnailX < 0 or levelThumbnailX > currentLevelThumbnail:getWidth()-view.width then
                levelThumbnailX = math.max(math.min(levelThumbnailX,currentLevelThumbnail:getWidth()-view.width),0)
                levelThumbnailXsp = -levelThumbnailXsp
            end

            if levelThumbnailY < 0 or levelThumbnailY > currentLevelThumbnail:getHeight()-view.height then
                levelThumbnailY = math.max(math.min(levelThumbnailY,currentLevelThumbnail:getHeight()-view.height),0)
                levelThumbnailYsp = -levelThumbnailYsp
            end

            levelThumbnailDX = math.lerp(levelThumbnailDX,levelThumbnailX,.05)
            levelThumbnailDY = math.lerp(levelThumbnailDY,levelThumbnailY,.05)
        end
    end
end

--Draw event
local function getXY(v)
    local x,y

    if type(v.x) == "function" then
        x = v.x()
    elseif type(v.x) == "table" then
        x = v.x[1]()+v.x[2]
    else
        x = v.x
    end
    
    if type(v.y) == "function" then
        y = v.y()
    elseif type(v.y) == "table" then
        y = v.y[1]()+v.y[2]
    else
        y = v.y
    end

    return x,y
end

local skinRender = {0,1,0,2}
local skinRate = 1/6

local blinkRate = 1/3

local skinQuad = love.graphics.newQuad(0,0,0,0,0,0)

local function draw()
    love.graphics.clear(38/255,48/255,73/255,1)

    parallaxShader:send("U_TIME",menuTime)

    --Draw stars
    for _,star in pairs(stars) do
        starQuad:setViewport(star.id*5,480,5,5,titleBG:getWidth(),titleBG:getHeight())

        love.graphics.draw(titleBG,starQuad,math.round(star.x),math.round(star.y),0,1,1,2,2)
    end

    love.graphics.setShader(parallaxShader)
    love.graphics.draw(titleBG,0,0)
    love.graphics.setShader()

    love.graphics.translate(0,-menuScroll)

    drawDescription = ""
    if menus[currentMenu] then
        for i,v in pairs(menus[currentMenu].render) do
            if v.type == "image" then
                local x,y = getXY(v)

                local xOff = v.arg.xAlign and v.data:getWidth() * v.arg.xAlign or 0
                local yOff = v.arg.yAlign and v.data:getHeight() * v.arg.yAlign or 0

                love.graphics.draw(v.data,x,y,0,1,1,xOff,yOff)
            elseif v.type == "text" then
                local x,y = getXY(v)
                local text = v.data

                drawText(text,x,y,unpack(v.arg))
            elseif v.type == "levels" then
                local x,y = getXY(v)

                drawText("Loaded Stages",x,y,1,1,1,false)

                local yoff = 0
                for i,v in pairs(serverLevels) do
                    yoff = yoff + 12
                    drawText(string.upper(i),x+12,y+yoff,1,1,1,false)
                    for _,stg in pairs(v) do
                        yoff = yoff + 12
                        drawText(stg.name,x+24,y+yoff,1,1,1,false)
                    end
                end
            elseif v.type == "levelThumbnail" then
                if serverLevels[serverInfo.gamemode][serverInfo.selectedLevel+1] then
                    local currentLevelThumbnail = serverLevels[serverInfo.gamemode][serverInfo.selectedLevel+1].thumbnail

                    if currentLevelThumbnail then
                        love.graphics.draw(currentLevelThumbnail,-math.round(levelThumbnailDX),-math.round(levelThumbnailDY))
                    end
                end
            end
        end

        local baseY = menus[currentMenu].optionsOff or view.height/2
        local frame = math.floor(love.timer.getTime()/skinRate)%4

        if menus[currentMenu] and #menus[currentMenu].options > 0 then
            skinQuad:setViewport(skinRender[frame+1]*16,customSkinImage and 0 or clientInfo.skin*16,16,16,myChar:getWidth(),customSkinImage and 16 or myChar:getHeight())

            love.graphics.setColor(0.1,0.1,0.1,0.5)
            love.graphics.draw(customSkinImage or myChar,skinQuad,view.width/2-68+1,baseY-2+(currentOption*16)+1)
            love.graphics.setColor(1,1,1,1)
            love.graphics.draw(customSkinImage or myChar,skinQuad,view.width/2-68,baseY-2+(currentOption*16))
        end

        for i,v in pairs(menus[currentMenu].options) do
            local text = v[1]
            
            if type(v[1]) == "function" then
                text = v[1]()
            end

            if v[2] == "set" then
                local dat = v[3]

                local underBlink = (typing and currentOption == (i-1)) and math.floor(love.timer.getTime()/blinkRate)%2 == 1

                if dat[2] == "bool" then
                    text = text..(dat[1][dat[3]] and ": On" or ": Off")
                elseif dat[2] == "number" then
                    text = text..": "..tostring(dat[1][dat[3]])
                elseif dat[2] == "string" then
                    text = text..": "..dat[1][dat[3]]..(underBlink and "_" or "")
                end
            elseif v[2] == "skin" then
                text = text..": "..(customSkinImage and "Custom Skin" or (skins[clientInfo.skin+1] or "null"))

                if customSkinImage == nil then
                    skinSelect = math.lerp(skinSelect,0,0.1)
                    local skinDiff = skinSelect

                    for iv=-3+skinDiff,3+skinDiff do
                        --Current
                        local ds = math.round((clientInfo.skin-skinDiff)+iv)%#skins
                        local walkFrame = ds == clientInfo.skin and skinRender[frame+1]*16 or 0

                        skinQuad:setViewport(walkFrame,ds*16,16,16,myChar:getWidth(),myChar:getHeight())

                        local vis = 1-(math.sin(math.rad(math.abs(iv)/3.5)*90))

                        local sin = math.cos(math.rad(math.abs(iv)/3.5*90))*32

                        love.graphics.setColor(0.1,0.1,0.1,(1-((1-vis)*2))/2)
                        love.graphics.draw(myChar,skinQuad,view.width/2+(iv*sin)+1,baseY+(i*16)+1,0,(sin/32)*2-1,1,8,0)
                        love.graphics.setColor(1,1,1,vis)
                        love.graphics.draw(myChar,skinQuad,view.width/2+(iv*sin),baseY+(i*16),0,(sin/32)*2-1,1,8,0)
                    end
                else
                    local walkFrame = skinRender[frame+1]*16

                    skinQuad:setViewport(walkFrame,0,16,16,customSkinImage:getWidth(),customSkinImage:getHeight())

                    love.graphics.setColor(0.1,0.1,0.1,0.5)
                    love.graphics.draw(customSkinImage,skinQuad,view.width/2+1,baseY+(i*16)+1,0,1,1,8,0)
                    love.graphics.setColor(1,1,1,1)
                    love.graphics.draw(customSkinImage,skinQuad,view.width/2,baseY+(i*16),0,1,1,8,0)
                end
            elseif v[2] == "level" then
                text = text..": "..(serverLevels[serverInfo.gamemode][serverInfo.selectedLevel+1] and serverLevels[serverInfo.gamemode][serverInfo.selectedLevel+1].name or "NONE")
            elseif v[2] == "joinalt" then
                if v[3][2] and i == currentOption+1 then
                    drawDescription = (text.."\n\n"..v[3][2])
                end
            end

            drawText(text,view.width/2-48,baseY+((i-1)*16),1,1,1)
        end
    end

    love.graphics.origin()
    --Draw Description
    if drawDescription:len() > 0 then
        drawText(drawDescription,8,32,1,1,1,false,false,view.width/2-76)
    end

    --Draw the error message at the bottom
    local qmT = love.timer.getTime()-errorMessage[2]
    local qmDY = 12-(math.max(0,qmT-3)*16)

    local qmW = string.len(errorMessage[1])*6

    love.graphics.setColor(0,0,0,0.5)
    love.graphics.rectangle("fill",view.width/2-(qmW/2+4),view.height-qmDY-2,qmW+8,16,4,4)

    drawText(errorMessage[1],view.width/2,view.height-qmDY,1,1,1,true)
end

return {update,draw}