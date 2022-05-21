fadePer = 1
fadeDirection = 1
fadeReverse = true
fadeFunction = nil
fadeData = nil

fadeImage = love.graphics.newImage("assets/Fade.png")
fadeImage:setWrap("repeat","repeat")
fadeQuad = love.graphics.newQuad(0,0,0,0,0,0)

function horFade(reversed)
    local segs = math.ceil(view.width/16 - 1) + 16

    local frame = 1 / (segs + 1)
    for x=0,segs do
        local per = 1-((x / (segs + 1))) - (1-fadePer)

        local thisFrame = math.max(0,math.min(per/frame,15))
        
        fadeQuad:setViewport(math.floor(thisFrame)*16,0,16,view.height,256,16)
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(fadeImage,fadeQuad,reversed and (view.width - (x*16)) or (x*16),0)
    end
end

function verFade(reversed)
    local segs = math.ceil(view.height/16 - 1) + 16

    local frame = 1 / (segs + 1)
    for x=0,segs do
        local per = 1-((x / (segs + 1))) - (1-fadePer)

        local thisFrame = math.max(0,math.min(per/frame,15))
        
        fadeQuad:setViewport(math.floor(thisFrame)*16,0,16,view.width,256,16)
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(fadeImage,fadeQuad,view.width,reversed and (view.height - (x*16)) or (x*16),math.rad(90))
    end
end

function midFade()
    love.graphics.setColor(0,0,32/255,fadePer)
    love.graphics.rectangle("fill",0,0,view.width,view.height)
end

local fadeSeconds = 36/50
function updateFade(dt)
    if fadeReverse then
        fadePer = math.max(fadePer - dt/fadeSeconds,0)
    else
        fadePer = fadePer + dt/fadeSeconds

        if fadePer >= 1 then
            (fadeFunction)(unpack(fadeData))

            --Continue fade in opposite direction (but played in reverse)
            if fadeDirection == 0 then
                fadeDirection = 2
            elseif fadeDirection == 1 then
                fadeDirection = 3
            elseif fadeDirection == 2 then
                fadeDirection = 0
            elseif fadeDirection == 3 then
                fadeDirection = 1
            end

            fadePer = 1
            fadeReverse = true
        end
    end
end

function renderFade()
    if fadeDirection == 0 then
        horFade(true)
    elseif fadeDirection == 1 then
        verFade(true)
    elseif fadeDirection == 2 then
        horFade(false)
    elseif fadeDirection == 3 then
        verFade(false)
    elseif fadeDirection == 4 then
        midFade()
    end
end