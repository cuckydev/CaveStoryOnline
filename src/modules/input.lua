keyMap = {left="left",up="up",right="right",down="down",jump="z",fire="x"}

pressedKeys = {}
typeInput = ""

function bindDown(bind)
    return love.keyboard.isDown(keyMap[bind])
end

function bindPressed(bind)
    return pressedKeys[keyMap[bind]] or false
end

function love.keypressed(key)
    pressedKeys[key] = true
end

function love.textinput(key)
    typeInput = typeInput..key
end

local function update()
    for i,v in pairs(pressedKeys) do
        pressedKeys[i] = nil
    end
    
    typeInput = ""
end

return update