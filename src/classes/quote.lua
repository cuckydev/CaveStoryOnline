quote = class("quote")

weapons = {
    [2] = {
        name = "Polar Star",
        ammo = -1,

        animationOffsets = {
            --Broken up into x and y
            null = {0,0},

            idleAnimation = {4,0},
            idleUpAnimation = {4,-3},

            inspectAnimation = {4,0},

            walkAnimation = {4,-1,4,0,4,-1,4,0},
            walkUpAnimation = {4,-4,4,-3,4,-4,4,-3},

            jumpAnimation = {4,-1},

            fallAnimation = {4,-1},
            fallUpAnimation = {4,-4},

            lookDownAnimation = {4,4},
        },

        shootSounds = {
            love.audio.newSource("assets/sfx/shoot2.wav","static"),
            love.audio.newSource("assets/sfx/shoot2.wav","static"),
            love.audio.newSource("assets/sfx/shoot2.wav","static"),
        },

        expNeeded = {
            10,20,10
        }
    }
}

function quote:bringCamera()
    camera.x = self.x - view.width/2/unitScale
    camera.y = self.y - view.height/2/unitScale

    camera.tgt_x = camera.x
    camera.tgt_y = camera.y

    self.camOffX = 0
    self.camOffY = 0
end

function quote:initialize(x,y)
    --Position
    self.x = x or 0 --I think these are obvious ;)
    self.y = y or 0 --spoiler alert: Quote's position

    self:bringCamera()

    --[[SECTION]]-- Movement
    self.walkSpeed = 0x32C --top speed
    self.walkAcceleration = 0x55 --applied when left or right is held (on ground of course).

    self.airAcceleration = 0x20

    self.friction = 0x33 --note: if walkAcceleration is less than (or equal to) friction Quote CANNOT move.

    self.maxSpeed = 0x5FF
    self.fallSpeed = 0x5FF

    self.holdGravity = 0x20
    self.gravity = 0x50

    self.jumpSpeed = -0x500

    self.booster2Speed = 0x5FF

    self.forces = {-0x88,0x00,0x00,-0x80,0x88,0x00,0x00,0x55} --wind and water current

    self.hitbox = {0xA00,0x1000,0xA00,0x1000}
                 --Vertical Width, Vertical Height, Horizontal Width, Horizontal Height
                 --BIG MODE: {0x3000,0x2000,0x2000,0x3000}

    --Friction is done interestingly, it makes turning around quick, without anything like a turn-around variable.

    self.facing = 1

    self.xsp = 0
    self.ysp = 0

    --Weapons and such
    self.weapons = {
        [2] = {level=1,exp=0,ammo=-1,maxammo=-1},
    }

    self.weaponSwitchFrame = 0
    self.weaponSwitchDirection = 0

    self.shootT = 0

    self.weapon = 2--0 --what weapon quote is holding, 0 is none

    --Camera stuff
    self.camOffX = 0
    self.camOffY = 0

    --Health
    self.hp = 0
    self.maxhp = 0

    self.spawned = true
    self.dead = false

    self.flicker = 0
    self.flickerVisible = true

    --States?
    self.grounded = true
    self.underwater = false

    self.inspecting = false
    self.interacted = false
    
    self.inputLocked = false

    --Booster variables
    self.currentBooster = 2 --0 - none, 1 - 0.8, 2 - 2.0

    self.boosterX = 0
    self.boosterY = 0

    self.usingBooster = false

    self.boosterFuel = 999999

    self.boosterSputtering = false
    
    --Just a bunch of animations
    self.idleAnimation = {0}
    self.idleUpAnimation = {3}

    self.inspectAnimation = {7}

    self.walkAnimation = {1,0,2,0}
    self.walkUpAnimation = {4,3,5,3}

    self.jumpAnimation = {2}

    self.fallAnimation = {1}
    self.fallUpAnimation = {4}

    self.lookDownAnimation = {6}

    self.frame = 0 --Animation frame (you know, into the animation itself? not what frame of the character sheet is drawing.)
    self.lastDrawnFrame = 0

    self.animation = self.idleAnimation --idle animation is default
    self.resetAnimation = false --when active, reset animation frame to 0 (reset when first set, of course when constantly set to true in update, it's always reset)

    self.animationSpeed = 0 --this is added onto the animation frame every frame

    self.armsImage = armsImage --Weapons, basically

    self.image = myChar --Quote
    self.quad = love.graphics.newQuad(0,0,0,0,0,0) --This quad is used both for Quote and the gun

    --Sounds
    self.jumpSound = love.audio.newSource("assets/sfx/jump.wav","static")

    self.boosterSound = love.audio.newSource("assets/sfx/booster.wav","static")

    self.landSound = love.audio.newSource("assets/sfx/land.wav","static")

    self.hurtSound = love.audio.newSource("assets/sfx/damage.wav","static")
    self.deathSound = love.audio.newSource("assets/sfx/death.wav","static")
end

function quote:groundUpdate()
    if bindDown("left") and self.inputLocked == false then
        self.inspecting = false

        if self.xsp >= -self.walkSpeed then
            self.xsp = math.max(-self.walkSpeed,self.xsp - self.walkAcceleration)
        end

        self.facing = -1
    end

    if bindDown("right") and self.inputLocked == false then
        self.inspecting = false

        if self.xsp <= self.walkSpeed then
            self.xsp = math.min(self.walkSpeed,self.xsp + self.walkAcceleration)
        end

        self.facing = 1
    end

    if bindDown("up") and self.inputLocked == false then
        self.inspecting = false
    end

    self.xsp = math.max(0,math.abs(self.xsp)-self.friction)*math.sign(self.xsp)

    local idleAnimation = bindDown("up") and self.idleUpAnimation or self.idleAnimation
    local walkAnimation = bindDown("up") and self.walkUpAnimation or self.walkAnimation
    
    if bindDown("left") or bindDown("right") then
        self.animation = walkAnimation
        self.animationSpeed = 1/5
    else
        self.resetAnimation = true
        self.animation = idleAnimation
        self.animationSpeed = 0
    end

    if bindPressed("jump") and self.inputLocked == false then
        self.ysp = self.jumpSpeed
        self.grounded = false

        self.jumpSound:stop()
        self.jumpSound:play()

        self.inspecting = false
    elseif bindPressed("down") and bindDown("left") == false and bindDown("right") == false and bindDown("up") == false and self.inputLocked == false then
        self.inspecting = true
    end
end

function quote:die()
    self.deathSound:stop()
    self.deathSound:play()

    stopSong()

    respawnQuote()
end

function quote:damageBoost()
    self.hurtSound:stop()
    self.hurtSound:play()

    self.ysp = -0x400
    self.grounded = false

    self.flicker = love.timer.getTime() + 1
end

function quote:airUpdate()
    if bindDown("left") and self.inputLocked == false then
        if self.xsp >= -self.walkSpeed then
            self.xsp = math.max(-self.walkSpeed,self.xsp - self.airAcceleration)
        end

        self.facing = -1
    end
    if bindDown("right") and self.inputLocked == false then
        if self.xsp <= self.walkSpeed then
            self.xsp = math.min(self.walkSpeed,self.xsp + self.airAcceleration)
        end

        self.facing = 1
    end

    local jumpAnimation = (bindDown("up") and self.inputLocked == false) and self.fallUpAnimation or self.jumpAnimation
    local fallAnimation = (bindDown("up") and self.inputLocked == false) and self.fallUpAnimation or self.fallAnimation
    
    if bindDown("down") and bindDown("up") == false and self.inputLocked == false then
        self.animation = self.lookDownAnimation
    else
        if self.ysp > 0  then
            self.animation = fallAnimation
        else
            self.animation = jumpAnimation
        end
    end

    self.resetAnimation = true

    if bindPressed("jump") and self.inputLocked == false then
        if self.boosterFuel > 0 then
            if self.currentBooster == 2 then
                self.usingBooster = true
                self.boosterX = 0
                self.boosterY = -1

                if bindDown("up") then
                    self.boosterX = 0
                    self.boosterY = -1
                elseif bindDown("left") then
                    self.boosterX = -1
                    self.boosterY = 0
                elseif bindDown("right") then
                    self.boosterX = 1
                    self.boosterY = 0
                elseif bindDown("down") then
                    self.boosterX = 0
                    self.boosterY = 1
                end

                self.xsp = self.boosterX * self.booster2Speed
                self.ysp = self.boosterY * self.booster2Speed

                self:boosterExhaust()
            end
        end
    end
end

function quote:quitBoost2()
    --End the boost
    self.usingBooster = false

    --Half Quote's speed (depending on if he's going horizontally, or up) 
    if self.boosterY == 0 then
        self.xsp = self.xsp / 2
    elseif self.boosterY == -1 then
        self.ysp = self.ysp / 2
    end
    --Down doesn't change Quote's speed at all.
end

function quote:boosterExhaust()
    self.boosterSound:stop()
    self.boosterSound:play()
end

function quote:booster2Update()
    self.boosterFuel = self.boosterFuel - 1 --1 frame tapping booster 2 causes infinite repulsion?

    if bindDown("jump") and self.inputLocked == false then
        if self.boosterFuel > 0 then
            if self.boosterY == 0 then
                --Quote is pushed up when he boosts into a wall, he also keeps this momentum until the end of the boost.
                local colliding = false

                local checkRectangle = {x=self.x-self.hitbox[3]-1,y=self.y-self.hitbox[4]/2,w=self.hitbox[3]*2+2,h=self.hitbox[4]} --a TINY bit larger, are we right up to a wall?
                
                local collideTiles = getTilesInRectangle(checkRectangle)

                --Set up tiles to detect (excluding slopes) solid tiles
                for i=#collideTiles,1,-1 do
                    local type = collideTiles[i].type

                    if not (type == 0x41) then
                        table.remove(collideTiles,i)
                    end
                end
                
                if #collideTiles > 0 then
                    self.ysp = -0x100
                end

                --Quote can turn around during a boost, tapping a direction will keep Quote turning in that direction.
                local acc = 0x20

                if bindDown("left") then
                    self.facing = -1
                end
                
                if bindDown("right") then
                    self.facing = 1
                end

                if self.xsp*self.facing < self.booster2Speed then
                    self.xsp = self.xsp + acc * self.facing

                    --Cap Quote's speed
                    if self.xsp*self.facing > self.booster2Speed then
                        self.xsp = self.booster2Speed * self.facing
                    end
                end
            else
                --Allow Quote to move left and right a bit
                if bindDown("left") then
                    if self.xsp >= -self.walkSpeed then
                        self.xsp = math.max(-self.walkSpeed,self.xsp - self.airAcceleration)
                    end
            
                    self.facing = -1
                end
                if bindDown("right") then
                    if self.xsp <= self.walkSpeed then
                        self.xsp = math.min(self.walkSpeed,self.xsp + self.airAcceleration)
                    end
            
                    self.facing = 1
                end

                --Push Quote up/down depending on boost
                if self.boosterY == -1 and self.ysp > -self.booster2Speed then
                    self.ysp = self.ysp - 0x20

                    if self.ysp < -self.booster2Speed then
                        self.ysp = -self.booster2Speed
                    end
                elseif self.boosterY == 1 and self.ysp < self.booster2Speed then
                    self.ysp = self.ysp + 0x20

                    if self.ysp > self.booster2Speed then
                        self.ysp = self.booster2Speed
                    end
                end
            end

            if (self.boosterFuel % 3) == 1 then
                self:boosterExhaust()
            end
        else
            self:quitBoost2()
        end
    else
        self:quitBoost2()
    end

    local jumpAnimation = bindDown("up") and self.fallUpAnimation or self.jumpAnimation
    local fallAnimation = bindDown("up") and self.fallUpAnimation or self.fallAnimation
    
    if bindDown("down") and not bindDown("up") then
        self.animation = self.lookDownAnimation
    else
        if self.ysp > 0  then
            self.animation = fallAnimation
        else
            self.animation = jumpAnimation
        end
    end

    self.resetAnimation = true
end

local slopeHeights = {
    [0] = {tileSize,0x1000},
    [1] = {0x1000,0},
    [2] = {0,0x1000},
    [3] = {0x1000,tileSize},
    [4] = {tileSize,0x1000},
    [5] = {0x1000,0},
    [6] = {0,0x1000},
    [7] = {0x1000,tileSize},
}

function quote:collisionRectangle(dir,hault,apply,determineGrounded)
    local collided = false

    local wasGrounded = self.grounded
    local prevYsp = self.ysp
    if determineGrounded then
        self.grounded = false
    end

    local horizontal = string.sub(dir,1,1) == "h"
    local mult = string.sub(dir,2,2) == "p" and 1 or -1

    if horizontal then
        local checkRectangle = {x=self.x,y=self.y-self.hitbox[4]/2,w=(self.hitbox[3]+math.max(self.xsp*mult,0))*mult,h=self.hitbox[4]}--{x=cx,y=cy-3,w=(5+math.max(cxs*mult,0))*mult,h=6}
        local collideTiles = getTilesInRectangle(checkRectangle)

        --Set up tiles to detect (excluding slopes) solid tiles
        for i=#collideTiles,1,-1 do
            local type = collideTiles[i].type

            if not (type == 0x41) then
                table.remove(collideTiles,i)
            end
        end

        if #collideTiles > 0 then
            collided = true

            if determineGrounded then
                self.grounded = true
                self.boosterFuel = 50
                self.usingBooster = false
            end

            xSort = function(a,b)
                return mult == 1 and (a.x < b.x) or mult == -1 and (a.x > b.x)
            end

            table.sort(collideTiles,xSort)
            
            self.x = mult == 1 and (collideTiles[1].x-self.hitbox[3]) or mult == -1 and (collideTiles[1].x+tileSize+self.hitbox[3])

            if hault then
                local dheld = (bindDown("left") and mult == -1) or (bindDown("right") and mult == 1)
                local bXSP = dheld and math.min(0x180,math.abs(self.xsp))*math.sign(self.xsp) or 0

                self.xsp = bXSP
            end
        end

        if collided == false and apply then
            self.x = self.x + self.xsp
        end
    else
        local add = (mult == 1 and wasGrounded) and self.maxSpeed or 0

        local checkRectangle = {x=self.x-self.hitbox[1]/2,y=self.y,w=self.hitbox[1],h=(self.hitbox[2]+math.max(self.ysp*mult,0))*mult+add}--{x=cx-3,y=cy,w=6,h=((mult == 1 and 8 or 7)+math.max(cys*mult,0))*mult}
        local collideTiles = getTilesInRectangle(checkRectangle)

        --Set up tiles to detect solid tiles
        for i=#collideTiles,1,-1 do
            local type = collideTiles[i].type

            if (type == 0x41) then
                --Keep
            elseif mult == 1 and ((type >= 0x54 and type <= 0x57) or (type >= 0x74 and type <= 0x77)) then
                local slopeType = (type-0x50)%0x20
                local xOff = (self.x - collideTiles[i].x)/tileSize

                if slopeHeights[slopeType] and xOff >= 0 and xOff <= 1 then
                    local expected = (collideTiles[i].y+tileSize) - math.lerp(slopeHeights[slopeType][1],slopeHeights[slopeType][2],xOff) --slopeHeights[slopeType][xOff+1]

                    if checkRectangle.y+checkRectangle.h >= expected then
                        --Keep (whew)
                    else
                        table.remove(collideTiles,i)
                    end
                else
                    table.remove(collideTiles,i)
                end
            elseif mult == -1 and ((type >= 0x50 and type <= 0x53) or (type >= 0x70 and type <= 0x73)) then
                local slopeType = (type-0x50)%0x20
                local xOff = math.max(math.min((self.x - collideTiles[i].x)/tileSize,1),0)

                if slopeHeights[slopeType] then
                    local expected = (collideTiles[i].y) + math.lerp(slopeHeights[slopeType][1],slopeHeights[slopeType][2],xOff) --slopeHeights[slopeType][xOff+1]

                    if checkRectangle.y+checkRectangle.h <= expected then
                        --Keep (whew)
                    else
                        table.remove(collideTiles,i)
                    end
                else
                    table.remove(collideTiles,i)
                end
            else
                table.remove(collideTiles,i)
            end
        end

        if #collideTiles > 0 then
            ySort = function(a,b)
                return mult == 1 and (a.y < b.y) or mult == -1 and (a.y > b.y)
            end

            table.sort(collideTiles,ySort)

            local type = collideTiles[1].type
            local slope = ((type >= 0x50 and type <= 0x57) or (type >= 0x70 and type <= 0x77))

            local dontGround = (wasGrounded and self.ysp < 0)

            if determineGrounded and dontGround == false then
                self.grounded = true
                self.boosterFuel = 50
                self.usingBooster = false
            end
            
            if slope then
                local slopeType = (type-0x50)%0x20
                local xOff = math.max(math.min((self.x - collideTiles[1].x)/tileSize,1),0)

                local ceil = slopeType < 4

                if slopeHeights[slopeType] then
                    local ht = math.lerp(slopeHeights[slopeType][1],slopeHeights[slopeType][2],xOff)
                    --ht = math.max(math.min(ht,1),0)
                    local expected = ceil and (collideTiles[1].y + ht) or ((collideTiles[1].y+tileSize) - ht)

                    self.y = math.round(ceil and (expected+self.hitbox[2]) or (expected-self.hitbox[2]))
                end
            else
                self.y = mult == 1 and (collideTiles[1].y-self.hitbox[2]) or mult == -1 and (collideTiles[1].y+tileSize+self.hitbox[2])
            end

            if hault and dontGround == false then
                self.ysp = 0
            end
        end

        if collided == false and apply then
            self.y = self.y + self.ysp
        end
    end

    if wasGrounded == false and self.grounded then
        if prevYsp > 0x400 then
            self.landSound:stop()
            self.landSound:play()
        end
    end
end

function quote:collision()
    do --X collision
        local first = self.xsp < 0 and "hn" or "hp"
        local other = first == "hn" and "hp" or "hn"

        self:collisionRectangle(first,true,true,false)
        self:collisionRectangle(other,true,false,false)
    end

    do --Y collision
        local first = self.ysp < 0 and "vn" or "vp"
        local other = first == "vn" and "vp" or "vn"

        self:collisionRectangle(first,true,true,first == "vp")
        self:collisionRectangle(other,false,false,other == "vp")
    end

    local cenCheck = {x=self.x,y=self.y,w=0,h=0}

    do  --Wind/currents
        local collideTiles = getTilesInRectangle(cenCheck)

        --Set up tiles to detect (excluding slopes) solid tiles
        for i=#collideTiles,1,-1 do
            local type = collideTiles[i].type

            if (type < 0x80 or type%0x10 > 0x03) then
                table.remove(collideTiles,i)
            end
        end

        if #collideTiles > 0 then
            local type = collideTiles[1].type%0x10

            self.xsp = self.xsp + self.forces[(type*2)+1]
            self.ysp = self.ysp + self.forces[(type*2)+2]
        end
    end
end

local waterTiles = {0x02,0x60,0x61,0x62,0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0xA0,0xA1,0xA2,0xA3}

function quote:update()
    self.flickerVisible = not self.flickerVisible

    if self.spawned and self.dead == false then
        local cenCheck = {x=self.x,y=self.y,w=0,h=0}

        do  --Water physics
            local collideTiles = getTilesInRectangle(cenCheck)

            --Set up tiles to detect (excluding slopes) solid tiles
            for i=#collideTiles,1,-1 do
                local type = collideTiles[i].type
                local water = false

                for i=1,#waterTiles do
                    if type == waterTiles[i] then
                        water = true
                    end
                end

                if not water then
                    table.remove(collideTiles,i)
                end
            end

            if #collideTiles > 0 then
                self.underwater = true

                self.walkSpeed = 0x196 --top speed
                self.walkAcceleration = 0x2A --applied when left or right is held (on ground of course).

                self.airAcceleration = 0x10

                self.friction = 0x19 --note: if walkAcceleration is less than (or equal to) friction Quote CANNOT move.

                self.maxSpeed = 0x5FF
                self.fallSpeed = 0x2FF

                self.holdGravity = 0x10
                self.gravity = 0x28

                self.jumpSpeed = -0x280

                self.booster2Speed = 0x2FF
            else
                self.underwater = false

                self.walkSpeed = 0x32C --top speed
                self.walkAcceleration = 0x55 --applied when left or right is held (on ground of course).

                self.airAcceleration = 0x20

                self.friction = 0x33 --note: if walkAcceleration is less than (or equal to) friction Quote CANNOT move.

                self.maxSpeed = 0x5FF
                self.fallSpeed = 0x5FF

                self.holdGravity = 0x20
                self.gravity = 0x50

                self.jumpSpeed = -0x500

                self.booster2Speed = 0x5FF
            end
        end
        
        local gravityEnabled = true

        if self.grounded then
            self:groundUpdate()
        else
            self.inspecting = false

            if self.usingBooster and self.currentBooster == 2 then
                self:booster2Update()
            else
                self:airUpdate()
            end
        end

        if self.usingBooster and self.currentBooster == 2 then
            gravityEnabled = false --We don't want this, haha.
        end

        --Shoot
        if self.hp > 0 and self.weapon > 0 and self.shootT < love.timer.getTime() and bindPressed("fire") then
            if client then
                local d = "right"
                
                local s,e = pcall(function()
                    d = (bindDown("up") and "up") or (((self.grounded == false) and bindDown("down")) and "down") or ((self.facing > 0) and "right") or ((self.facing < 0) and "left")
                end)

                local angle = d == "up" and math.rad(90) or d == "down" and math.rad(-90) or 0

                self.shootT = love.timer.getTime()+0.05

                weapons[self.weapon].shootSounds[1]:stop()
                weapons[self.weapon].shootSounds[1]:play()

                client:send("bulletSpawn",{aliveTime=8,weapon=self.weapon,level=1,angle=angle,xsp=(d == "left" and -0x1000 or d == "right" and 0x1000) or 0,ysp=(d == "up" and -0x1000 or d == "down" and 0x1000) or 0,xoff=0,yoff=(d == "left" or d == "right") and 0x600 or 0})
            end
        end

        --Gravity
        if gravityEnabled and self.ysp < self.fallSpeed then
            if bindDown("jump") and self.ysp < 0 then
                self.ysp = self.ysp + self.holdGravity
            else
                self.ysp = self.ysp + self.gravity
            end

            self.ysp = math.min(self.ysp,self.fallSpeed)
        end

        --Cap speed
        self.xsp = math.min(self.maxSpeed,math.abs(self.xsp))*math.sign(self.xsp)
        self.ysp = math.min(self.maxSpeed,math.abs(self.ysp))*math.sign(self.ysp)

        self:collision()

        if self.inspecting and self.grounded then
            self.animation = self.inspectAnimation
        else
            self.inspecting = false
        end

        local lastFrame = 0
        self.frame = (self.frame + self.animationSpeed) % #self.animation

        --Do some other stuff
        if self.resetAnimation then
            self.frame = 0
            self.resetAnimation = false
        end

        --Keep in bounds (left and right)
        self.x = math.max(0x1000,math.min(level.width*tileSize-0x1000,self.x))

        --Die if fell out of map
        if self.y > level.height*tileSize+0x3000 then
            self:die()
        end
    end

    --Do le camera
    local goalCOX = 0x8000 * self.facing
    local goalCOY = bindDown("up") and -0x8000 or bindDown("down") and 0x8000 or 0

    self.camOffX = math.approach(self.camOffX,goalCOX,0x200)
    self.camOffY = math.approach(self.camOffY,goalCOY,0x200)
end

function quote:draw()
    local drawFrame = (math.floor(self.frame)%#self.animation)+1
    local frameOffset = self.animation[drawFrame]*16

    self.lastDrawnFrame = self.animation[drawFrame]

    local drawX = self.x*unitScale
    local drawY = self.y*unitScale

    local animationName = "null"

    for v,i in pairs(self) do
        if i == self.animation and v ~= "animation" then
            animationName = v
        end
    end

    if self.spawned and (love.timer.getTime() > self.flicker or self.flickerVisible) and self.dead == false then
        love.graphics.setColor(1,1,1,1)

        if self.weapon > 0 then
            local offsetLookup = weapons[self.weapon].animationOffsets[animationName]
            local gunXOffset = offsetLookup[(drawFrame-1)*2+1]
            local gunYOffset = offsetLookup[(drawFrame-1)*2+2]

            local gunFrame = string.find(animationName,"Up") and 1 or string.find(animationName,"Down") and 2 or 0
            
            self.quad:setViewport((self.weapon)*24,gunFrame*16,24,16,self.armsImage:getWidth(),self.armsImage:getHeight())
            love.graphics.draw(self.armsImage,self.quad,math.round(drawX) + (gunXOffset * self.facing),math.round(drawY)+gunYOffset,0,self.facing,1,12,8)
        end
        
        self.image = customSkinImage or myChar

        self.quad:setViewport(frameOffset,customSkinImage and 0 or clientInfo.skin*16,16,16,self.image:getWidth(),self.image:getHeight())
        love.graphics.draw(self.image,self.quad,math.round(drawX),math.round(drawY),0,self.facing,1,8,8)
    end
end

return quote