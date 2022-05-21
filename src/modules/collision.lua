rects = {}

function rectIntersect(r1,r2)
    return (r1.x > r2.x-r1.w and r1.x < r2.x+r2.w) and (r1.y > r2.y-r1.h and r1.y < r2.y+r2.h)
end

function levelBoundClamp(x,t)
    if t == "x" then
        return math.max(math.min(x,level.width*0x2000),0)
    elseif t == "y" then
        return math.max(math.min(x,level.height*0x2000),0)
    end
end

function getTilesInRectangle(rectangle)
    if level then
        --Axis aligned shit
        local tiles = {}

        local left = math.min(rectangle.x,rectangle.x+rectangle.w)
        left = levelBoundClamp(left,"x")
        local right = math.max(rectangle.x,rectangle.x+rectangle.w) --Support for negative width??
        right = levelBoundClamp(right,"x")

        local top = math.min(rectangle.y,rectangle.y+rectangle.h)
        top = levelBoundClamp(top,"y")
        local bottom = math.max(rectangle.y,rectangle.y+rectangle.h)-1 --.. and height (subtracted by 1, very little difference, just allows boosting through 1 tile corridors)
        bottom = levelBoundClamp(bottom,"y")

        local checkXStart = math.floor(left/tileSize)+1
        local checkXEnd = math.floor(right/tileSize)+1
        local checkYStart = math.floor(top/tileSize)+1
        local checkYEnd = math.floor(bottom/tileSize)+1

        if collisionDebug then
            left = left*unitScale
            right = right*unitScale
            top = top*unitScale
            bottom = bottom*unitScale
            table.insert(rects,{"fill",left,top,right-left,bottom-top})
        end

        for y=checkYStart,checkYEnd do
            if level.tiles[y] then
                for x=checkXStart,checkXEnd do
                    if level.tiles[y][x] then
                        local type = level.types[level.tiles[y][x]]

                        --local solid = ((type == 0x41) or (type >= 0x50 and type <= 0x57) or (type >= 0x70 and type <= 0x77))
                        tiles[#tiles+1] = {x=(x-1)*tileSize,y=(y-1)*tileSize,type=type}
                    end
                end
            end
        end

        return tiles
    end

    return {}
end