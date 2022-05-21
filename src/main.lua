sock = require("sock")

function math.sign(x)
    return x == 0 and 0 or x/math.abs(x)
end

function math.lerp(x,y,z)
    return x + (y-x) * z
end

function math.round(x,y)
    y = y or 1
    return math.floor(x/y+.5)*y
end

function math.approach(x,y,z)
    return x + math.min(math.abs(y-x),z)*math.sign(y-x)
end

server = nil
client = nil

serverInfo = {ip = "", port = "", gamemode = "ffa", name = "", selectedLevel = 0}

clientInfo = {username = "", skin = 0, myId = -1, connectTime = 0, wasConnected = false}

globalSettings = {rpc = true}

updateRPC = 0

noConnect = false

customSkinData = nil
customSkinImage = nil

errorMessage = {"",-math.huge}

currentMenu = "title"
currentOption = 0

version = "0.3.1"

skins = {
    "Quote",
    "Mimiga Mask Quote",
    "Beta Quote 1",
    "Beta Quote 2",
    "Beta Quote 3",
    "Beta Quote 4",
    "Beta Quote 5",
    "Curly",
    "Mimiga Mask Curly",
    "Sue",
    "Mimiga Mask Sue",
    "Toroko",
    "Mimiga Mask Toroko",
    "Santa",
    "Mimiga Mask Santa",
    "Plantation Worker",
    "Chaco",
    "Mimiga Mask Chaco",
    "Jack",
    "Mimiga Mask Jack",
    "Aar",
    "Labyrinth Robot",
    "Labyrinth Robot",
    "Colon",
    "Mahin",
}

camera = {x=0,y=0,speed=16,tgt_x=0,tgt_y=0}

clp = 0

tickRate = 0.05

userdat = {}
bullets = {}

function loadBinary(filename)
    local str = love.filesystem.read(filename)
    local tbl = {}

    for i=1,string.len(str) do
        tbl[#tbl+1] = string.byte(string.sub(str,i,i))
    end

    return tbl
end

function loadBinaryFromString(data)
    local tbl = {}

    for i=1,string.len(data) do
        tbl[#tbl+1] = string.byte(string.sub(data,i,i))
    end

    return tbl
end

function stringSplit(str,delimiter)
    local result = {}
    local from  = 1

    local delim_from, delim_to = string.find(str,delimiter,from)

    while delim_from do
        table.insert(result, string.sub(str,from,delim_from-1))
        from  = delim_to + 1
        delim_from, delim_to = string.find(str,delimiter,from)
    end

    table.insert(result,string.sub(str,from))
    return result
end

serverLevels = {ffa={}}

local saveSep = string.char(10)..string.char(20)

--Add string together (not concatenating)
function addStrings(str1,str2)
    local len = math.max(str1:len(),str2:len())
    local ret = ""

    str1 = str1..string.rep(string.char(0),len-str1:len())
    str2 = str2..string.rep(string.char(0),len-str2:len())

    for i=1,len do
        ret = ret..string.char((str1:byte(i)+str2:byte(i))%0x100)
    end

    return ret
end

function checksumEnumerate(folder, checksum)
    local files = love.filesystem.getDirectoryItems(folder)
    local ret = ""
    
	for i,v in ipairs(files) do
        local file = folder..v

		if love.filesystem.isFile(file) then
            local md5 = md5.sumhexa(love.filesystem.read(file))
            
            ret = addStrings(ret,md5)
        elseif v ~= "source" then
			ret = checksumEnumerate(file.."/", ret)
		end
    end

    return ret
end

function love.load(arg)
    local str = ""
    if arg then
        for i,v in pairs(arg) do
            str = str..("     ["..tostring(i).."] = "..tostring(v)).."\n"
        end
    end

    --Set default filter
    love.graphics.setDefaultFilter("nearest","nearest")
    
    --Require modules
    md5 = require("md5")
    utf8 = require("utf8")

    class = require("middleclass")

    json = require("modules.json")

    local derpInit = require("derp.init")
    derp = derpInit("449702076667265024")

    bulletCollide = require("modules.bulletCollide")

    inputUpdate = require("modules.input")

    apiclient = require("apiclient")

    --These don't return anything
    require("modules.org")
    require("modules.viewport")

    require("modules.level")
    require("modules.collision")

    require("modules.hud")

    require("modules.fade")

    --Load states
    clientUpdate,startClient = unpack(require("states.client"))
    serverUpdate,startServer = unpack(require("states.server"))

    menuUpdate,menuDraw = unpack(require("states.menu"))

    gameUpdate,gameDraw = unpack(require("states.game"))

    --Checksum
    --Set window title while this is going on (can't render directly to screen yet.)
    love.window.setTitle("Getting checksum...")
    checksum = checksumEnumerate("/","")

    --Final window title (includes version number)
    love.window.setTitle("Cave Story Online v"..version)

    love.filesystem.setIdentity("CaveStoryOnline")

    --Framerate
    min_dt = 1/60
    next_time = love.timer.getTime()

    gameTime = 0

    --Load Save
    if love.filesystem.getInfo("save.cso") then
        local saveVars = stringSplit(love.filesystem.read("save.cso"),";"..saveSep)

        for i=1,#saveVars do
            local varData = stringSplit(saveVars[i],":"..saveSep)

            if #varData > 0 then
                local variable = varData[1]
                local value = varData[2]

                if variable == "us" then
                    clientInfo.username = value
                elseif variable == "sk" then
                    clientInfo.skin = tonumber(value)
                elseif variable == "ws" then
                    view.widescreen = tonumber(value) ~= 0
                elseif variable == "ss" then
                    view.scale = tonumber(value)
                elseif variable == "es" then
                    view.compactHud = tonumber(value) ~= 0
                elseif variable == "rpc" then
                    globalSettings.rpc = tonumber(value) ~= 0
                end
            end
        end
    end

    if love.filesystem.getInfo("customSkin.png") then
        local imgDat = love.image.newImageData("customSkin.png")

        if inspectCustomSkin(imgDat) then
            customSkinData = love.filesystem.read("customSkin.png")
            customSkinImage = love.graphics.newImage("customSkin.png")
        end
    end

    --Viewport
    updateView()

    --Define unit scale
    unitScale = 1/0x200

    tileSize = 0x2000

    --Load background table
    currentBackground = {nil,nil}

    --Debugging features
    debugFont = love.graphics.newFont(14)

    collisionDebug = false

    showFPS = false
    showMemory = false
    showPing = false
    
    --Class and object system
    classes = {}
    objects = {}
    effects = {}

    player = nil --Current player object

    --Load images and quads
    do
        --Hud (and some variables for how it's rendered)
        hudImage = love.graphics.newImage("assets/Hud.png")
        armsHudImage = love.graphics.newImage("assets/ArmsImage.png")
        numberFont = love.graphics.newImageFont("assets/Numbers.png","0123456789/-",0)

        hudQuad = love.graphics.newQuad(0,0,0,0,0,0)

        --Load character images
        myChar = love.graphics.newImage("assets/MyChar.png")
        armsImage = love.graphics.newImage("assets/Arms.png")
        bulletImage = love.graphics.newImage("assets/Bullet.png")

        otherPlayerQuad = love.graphics.newQuad(0,0,0,0,0,0)

        --Entities
        entityImage = love.graphics.newImage("assets/Entities.png")

        --Other stuff
        windImage = love.graphics.newImage("assets/Wind.png")
        windImage:setWrap("repeat","repeat")

        --Font character map, image, and quad
        charMap = ' !"#$%&'.."'"..'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[¥]_`abcdefghijklmnopqrstuvwxyz{|}~'

        fontImage = love.graphics.newImage("assets/Font.png")
        fontQuad = love.graphics.newQuad(0,0,0,0,0,0)

        --Some more title stuff
        titleBG = love.graphics.newImage("assets/TitleBG.png")
        titleBG:setWrap("repeat","repeat")

        wifiImage = love.graphics.newImage("assets/Wifi.png")
    end

    --Load classes
    local dir = "classes/"
    local files = love.filesystem.getDirectoryItems(dir)

    for _, filename in ipairs(files) do
        classes[string.sub(filename,1,-5)] = require("classes."..string.sub(filename,1,-5))
    end

    --Audio (orgs were loaded beforehand)
    love.audio.setVolume(1)

    --Load sounds
    local dir = "assets/sfx/"
    local files = love.filesystem.getDirectoryItems(dir)

    sounds = {}

    for _, filename in ipairs(files) do
        sounds[string.sub(filename,1,-5)] = love.audio.newSource(dir..filename,"static")
    end

    --Define menus
    menus = {
        ["title"] = {
            render = {
                {type = "image", x = menuFunctions.getWidthDiv2, y = 8, data = love.graphics.newImage("assets/Title.png"), arg = {xAlign = 0.5}},
                {type = "text", x = 8, y = {menuFunctions.getHeight,-16}, data = "V"..version, arg = {1,1,1}}
            },

            options = {
                [1] = {"Join Server","goto","join"},
                [2] = {"Host Server","goto","host"},
                [4] = {"Options","goto","options"}
            },
        },
        ["join"] = {
            render = {
                {type = "text", x = menuFunctions.getWidthDiv2, y = 8, data = "Join Server", arg = {1,1,1,true}},
                {type = "text", x = menuFunctions.getWidthDiv2, y = 32, data = "Manual Join", arg = {1,1,1,true}},
                {type = "text", x = menuFunctions.getWidthDiv2, y = 92, data = "Servers", arg = {1,1,1,true}},
            },

            optionsOff = 48,
        },
        ["host"] = {
            render = {
                {type = "levelThumbnail", x = 0, y = 0, data = "", arg = {}},
                {type = "text", x = menuFunctions.getWidthDiv2, y = 8, data = "Host Server", arg = {1,1,1,true}},
                {type = "text", x = 8, y = {menuFunctions.getHeight,-16}, data = "If name is blank, server will be private.", arg = {1,1,1,false}},
                {type = "text", x = 8, y = {menuFunctions.getHeight,-32}, data = "Port is 12004", arg = {1,1,1,false}},
                {type = "levels", x = 8, y = 16, data = "", arg = {}}
            },

            options = {
                [1] = {"Stage","level",{}},
                [3] = {"Name","set",{serverInfo,"string","name",24}},
                [4] = {"Start Hosting","host",{}},
            },
        },
        ["options"] = {
            render = {
                {type = "text", x = menuFunctions.getWidthDiv2, y = 8, data = "Options", arg = {1,1,1,true}},
            },

            optionsOff = 64,

            options = {
                [1] = {"Username","set",{clientInfo,"string","username",18}},
                [2] = {"Skin","skin"},
                [5] = {"Discord Link","set",{globalSettings,"bool","rpc"}},
                [6] = {"Widescreen","set",{view,"bool","widescreen",updateView}},
                [7] = {"Screen Scale","set",{view,"number","scale",updateView,1,4}},
                [8] = {"Compact HUD","set",{view,"bool","compactHud"}},
            },
        },
        ["connecting"] = {
            render = {
                {type = "text", x = menuFunctions.getWidthDiv2, y = 8, data = "Connecting to server...", arg = {1,1,1,true}},
            },

            options = {},
        },
        ["hosting"] = {
            render = {
                {type = "text", x = menuFunctions.getWidthDiv2, y = 8, data = "Hosting server...", arg = {1,1,1,true}},
            },

            options = {},
        },
    }

    local success1,result1 = apiclient("GET", "http://api.ipify.org/", "")

    if success1 == false then
        noConnect = true

        loadSong("noconectado")
    else
        --Start game off on title screen
        goBackToTitle()

        if arg[1] then
            local lip = string.sub(arg[1],string.len("discord-706140770280931400://") + 1)

            for i=lip:len(),1,-1 do
                if lip:sub(i,i) == "/" then
                    lip = lip:sub(1,i-1)
                end
            end

            loadSong("access")

            --love.filesystem.write("log.txt",spl[#spl-1])
            startClient({lip})
        end
    end
end

function drawText(text,x,y,r,g,b,centered,rl,ww)
    ww = ww or math.huge

    local xs = string.len(text)*6

    local sx = (x - (centered and math.floor(xs / 2) or rl and xs or 0))

    local cx = 0

    local parse = stringSplit(text," ")

    for i=1,#parse do
        local npos = cx + (parse[i]:len()*6)

        if npos > ww then
            y = y + 12
            cx = 0 --Space is added after
        end
        
        for z=1,parse[i]:len() do
            if parse[i]:sub(z,z) == "\n" then
                y = y + 12
                cx = -6 --Space is added after
            else
                for v=1,charMap:len() do
                    if charMap:sub(v,v) == parse[i]:sub(z,z) then
                        local vx = (v-1)%(fontImage:getWidth()/6)
                        local vy = math.floor((v-1)/(fontImage:getWidth()/6))
                        fontQuad:setViewport(vx*6,vy*12,6,12,fontImage:getWidth(),fontImage:getHeight())

                        love.graphics.setColor(r*.1,g*.1,b*.1,1)
                        love.graphics.draw(fontImage,fontQuad,sx+cx+1,y+1)
                        love.graphics.setColor(r,g,b,1)
                        love.graphics.draw(fontImage,fontQuad,sx+cx,y)
                    end
                end
            end

            cx = cx + 6

            if cx >= ww then
                y = y + 12
                cx = 0 --Space is added after
            end
        end

        cx = cx + 6
    end
end

--End game and then save when window is closed.
function love.quit()
	if derp then
		derp.setRichPresence()
	end
	
    if client then
        justDisconnect()
    end

    if server then
        closeServer()
    end

    stopSong() --Make sure song ends

    --Save preferences
    local savDat = {rpc=(globalSettings.rpc and 1 or 0),us=clientInfo.username,sk=clientInfo.skin,ws=(view.widescreen and 1 or 0),ss=view.scale,es=(view.compactHud and 1 or 0)}
    local str = ""

    for i,v in pairs(savDat) do
        str = str..i..":"..saveSep..v..";"..saveSep
    end

    love.filesystem.write("save.cso",str)
end

function love.update(dt)
    playOrg.update(dt) --Update music

    if noConnect == false then
        next_time = next_time + min_dt
        gameTime = gameTime + 1

        if currentMenu then
            menuUpdate(dt)
        end

        if client then
            clientUpdate(dt)
        end

        if server then
            serverUpdate(dt)
        end

        inputUpdate()

        updateFade(dt)

        if globalSettings.rpc and server == nil then
            if updateRPC < love.timer.getTime() then
                local nextPresence = {
                    details = (currentMenu and "In the menu."),
                    assets = {
                        ["large_image"] = "main_icon",
                        ["large_text"] = "Cave Story Online",
                    },
                    instance = true,
                }

                if currentMenu == nil then
                    nextPresence.state = "IP: "..client:getAddress()
                    nextPresence.details = "FFA"
                    nextPresence.assets["small_image"] = "mode_ffa"
                    nextPresence.assets["small_text"] = "Free For All"
                end

                derp.setRichPresence(nextPresence)

                updateRPC = love.timer.getTime()+5 --update rpc every 5 seconds
            end

            derp.service()
        end
    end
end

function love.draw()
    love.graphics.setCanvas(view.canvas)
    love.graphics.clear(0,0,0)
    love.graphics.setColor(1,1,1,1)

    if noConnect then
        love.graphics.draw(wifiImage,view.width/2-16,-16,0,1,1,64,0)
        drawText("Not connected to the internet.",view.width/2,view.height/2-6,1,1,1,true,false)
        drawText("(Cave Story Online kind of needs it.)",view.width/2,view.height/2+8,1,1,1,true,false)

        love.graphics.setCanvas()

        love.graphics.setColor(1,1,1,1)
        love.graphics.origin()
        love.graphics.draw(view.canvas,0,0,0,view.scale,view.scale)
        return
    end

    if currentMenu then
        menuDraw()
    elseif client and client:isConnected() and level and level.loaded then
        gameDraw()
    end

    renderFade()

    love.graphics.setCanvas()

    love.graphics.setColor(1,1,1,1)
    love.graphics.origin()
    love.graphics.draw(view.canvas,0,0,0,view.scale,view.scale)

    --Draw some debug stuff
    local w,h = love.graphics.getDimensions()
    love.graphics.setFont(debugFont)
    love.graphics.setColor(1,1,1,1)

    local debugY = 8

    if showFPS then
        debugY = debugY + 16
        love.graphics.print("fps: "..tostring(love.timer.getFPS()),8,h-debugY)
    end

    if showMemory then
        debugY = debugY + 16

        local text = "memory: " .. tostring(math.floor((collectgarbage("count")/1024)/.1)*.1) .. "mb"
        love.graphics.print(text,8,h-debugY)
    end

    if showPing and client then
        debugY = debugY + 16

        local text = "ping: " .. tostring(math.floor(client:getRoundTripTime())).."ms"
        love.graphics.print(text,8,h-debugY)
    end

    local cur_time = love.timer.getTime()
    if next_time <= cur_time then
        next_time = cur_time
        return
    end
    love.timer.sleep(next_time - cur_time)
end