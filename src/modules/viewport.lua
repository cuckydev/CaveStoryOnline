view = {width=0,height=0,widescreen=true,scale=2,compactHud=true}

function updateView()
    view.width = view.widescreen and math.round(240*16/9,2) or 320
    view.height = 240

    love.window.setMode(view.width*view.scale,view.height*view.scale,{vsync=0})

    view.canvas = love.graphics.newCanvas(view.width,view.height)
end