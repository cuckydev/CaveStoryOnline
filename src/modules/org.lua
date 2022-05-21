--Main module
playOrg = require("org.play_org")

--Variables
orgs = {} --Loaded orgs (from the exe)
parsedLevelOrg = nil --Org sent from the level

--Load internal orgs
local dir = "assets/music/"
local files = love.filesystem.getDirectoryItems(dir)

for _, filename in ipairs(files) do
    local s,e = pcall(function() --Prevent full on error if failed
        local parse = playOrg.parse(dir .. filename)
        orgs[string.sub(filename,1,-5)] = parse
    end)
end

--Loading functions
function loadSong(songv) --For songs internally loaded into exe
    --Stop previously playing song
    stopSong()

    --Now play new song (if it exists, song not in exe, or couldn't be parsed)
    if orgs[songv] then
        playOrg.load(orgs[songv])
        playOrg.setVolume(1)
        playOrg.play()
    end
end

function loadLevelOrg(first) --For songs sent from the server
    --Stop previously playing song
    stopSong()

    --Create temp file if needed
    local dat = nil

    if first then
        local dir = love.filesystem.getSaveDirectory()
        local success,why = love.filesystem.write("tempOrg.org",level.org)

        dat = love.filesystem.newFile("tempOrg.org")
    end

    --Parse (if needed) and play org
    local s,e = pcall(function()
        if first and dat then
            parsedLevelOrg = playOrg.parse(dat)
        end
        
        playOrg.load(parsedLevelOrg)
        playOrg.setVolume(1)
        playOrg.play()
    end)

    --Now remove old temp file
    if first then
        --Remove
        dat:close()
        love.filesystem.remove("tempOrg.org")
    end
end

--Stopping function
function stopSong()
    playOrg.stop() --End
end