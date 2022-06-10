---@private
local function _missileEnding(isok, options, point)
    if (options.arrowToken ~= nil) then
        cj.DestroyEffect(options.arrowToken)
        options.arrowToken = nil
    end
    local res = isok
    if (res == true and type(options.onEnd) == "function") then
        res = options.onEnd(options, point)
    end
    if (res == true and (options.reflex or 0) > 0) then
        if (options.targetUnit ~= nil) then
            local g = hgroup.createByXY(point[1], point[2], 600, function(enumUnit)
                return false == hunit.isUnit(options.targetUnit, enumUnit) and hunit.isEnemy(options.sourceUnit, enumUnit) and hunit.isAlive(enumUnit)
            end)
            local nextUnit = table.random(g, 1)
            if (nextUnit) then
                missile({
                    model = options.model,
                    scale = options.scale,
                    sourceUnit = options.sourceUnit,
                    speed = options.speed,
                    height = options.height * 0.9,
                    acceleration = options.acceleration,
                    shake = options.shake,
                    shakeOffset = options.shakeOffset,
                    reflex = options.reflex - 1,
                    onEnd = options.onEnd,
                    sourcePoint = point,
                    targetUnit = nextUnit,
                })
            end
        end
    end
end

--[[
    虚拟箭矢
    model = nil, --[必须]虚拟箭矢的特效
    animateScale = 1.00, --[可选]虚拟箭矢的动画速度，默认1
    scale = 1.00, --[可选]虚拟箭矢的模型缩放，默认1
    speed = 500, --[可选]每秒冲击的距离，默认1秒500px
    acceleration = 0, --[可选]冲击加速度，每个周期[0.02秒]都会增加一次
    height = 0, --[可选]飞跃高度，默认0
    shake = 0, --[可选]摇摆角度[number|'rand']默认0
    sourceUnit, --[必须]伤害来源
    targetUnit, --[可选]目标单位（有单位目标，那么冲击跟踪到单位就结束）
    sourcePoint = number[3][可选]强制设定初始坐标
    targetPoint = number[3][可选]强制设定目标坐标
    onMove = noteAbilityMissileOnMove, --[可选]每周期回调,当return false时可强行中止循环
    onEnd = noteAbilityMissileOnEnd, --[可选]结束回调
]]
---@alias noteAbilityMissileOnMove fun(options:table,point:number[]):nil|boolean
---@alias noteAbilityMissileOnEnd fun(options:table,point:number[]):nil|boolean
---@alias noteAbilityMissileOptions {model:string,animateScale:number,scale:number,speed:number,acceleration:number,height:number,shake:number,sourceUnit:userdata,targetUnit:userdata,sourcePoint:number[],targetPoint:number[],onMove:noteAbilityMissileOnMove,onEnd:noteAbilityMissileOnEnd}
---@param options noteAbilityMissileOptions
function missile(options)
    local sourceUnit = options.sourceUnit
    local targetUnit = options.targetUnit
    local frequency = 0.02
    options.animateScale = options.animateScale or 1
    options.scale = options.scale or 1
    options.acceleration = options.acceleration or 0
    local speed = math.min(5000, math.max(100, options.speed or 500))

    ---@type number[]
    local sPoint = options.sourcePoint
    ---@type number[]
    local tPoint
    if (type(options.targetPoint) == "table") then
        tPoint = { options.targetPoint[1], options.targetPoint[2], options.targetPoint[3] }
    else
        tPoint = { hunit.x(targetUnit), hunit.y(targetUnit), hunit.h(targetUnit) }
    end
    local fac0 = math.angle(hunit.x(sourceUnit), hunit.y(sourceUnit), tPoint[1], tPoint[2])
    if (sPoint == nil) then
        local sx, sy = math.polarProjection(hunit.x(sourceUnit), hunit.y(sourceUnit), 30, fac0)
        sPoint = { sx, sy, hunit.h(sourceUnit) }
    end

    local distance0 = math.distance(sPoint[1], sPoint[2], tPoint[1], tPoint[2])
    local dtStep = distance0 / speed / frequency
    local dtSpd = 1 / dtStep
    local dtAcl = 0

    local rotateY0 = 0
    local height
    if (sPoint[3] >= tPoint[3]) then
        height = sPoint[3] + options.height
        rotateY0 = -math_rad2deg * math.atan(height, distance0 / 2)
    else
        height = tPoint[3] + options.height / 2
        rotateY0 = -math_rad2deg * math.atan(height, distance0 / 2)
    end
    if (fac0 > 90 and fac0 < 270) then
        rotateY0 = -rotateY0
    end
    local dtRot = 2.2 * rotateY0 / dtStep

    local hh = height * 0.6
    if (distance0 < hh) then
        height = height * (distance0 / hh)
    end
    height = height + math.random(-15, 15)

    local shake = options.shake
    local mh
    if (shake == "rand") then
        shake = math.random(0, 359)
    elseif (type(shake) == "number") then
        shake = math.ceil(shake) % 360
    else
        shake = 0
    end
    if (shake < 180) then
        mh = distance0 / 2
    else
        mh = distance0 / 1.5
    end

    local mx, my = math.polarProjection(sPoint[1], sPoint[2], mh, fac0 + shake)
    local mPoint = { mx, my, 1.5 * height }

    local oriX, oriY = sPoint[1], sPoint[2]
    options.arrowToken = cj.AddSpecialEffect(options.model, sPoint[1], sPoint[2])
    hjapi.EXSetEffectZ(options.arrowToken, sPoint[3])
    hjapi.EXSetEffectSpeed(options.arrowToken, options.animateScale)
    hjapi.EXSetEffectSize(options.arrowToken, options.scale)
    hjapi.EXEffectMatRotateZ(options.arrowToken, fac0)
    hjapi.EXEffectMatRotateY(options.arrowToken, rotateY0)
    local dt = 0
    local distanceCur = distance0
    local distancePrev
    local collision = 50
    local faraway = frequency * speed * 30
    local cPoint = { sPoint[1], sPoint[2], sPoint[3] }
    local fac = fac0
    local rotateY = rotateY0
    htime.setInterval(frequency, function(curTimer)
        if (options.arrowToken == nil or hunit.isDestroyed(sourceUnit) or (targetUnit ~= nil and hunit.isDestroyed(targetUnit))) then
            curTimer.destroy()
            _missileEnding(false, options, cPoint)
            return
        end
        local di = 1
        if (type(options.targetPoint) ~= "table") then
            tPoint = { hunit.x(targetUnit), hunit.y(targetUnit), hunit.h(targetUnit) }
            di = distance0 / distanceCur
        end
        di = math.min(1, di)
        dt = dt + dtSpd * di
        if (options.acceleration > 0) then
            dtAcl = 1 / (distance0 / options.acceleration / frequency)
            dtSpd = dtSpd + dtAcl
        end

        local nPoint = {
            sPoint[1] + 2 * (mPoint[1] - sPoint[1]) * dt + (tPoint[1] - 2 * mPoint[1] + sPoint[1]) * dt ^ 2,
            sPoint[2] + 2 * (mPoint[2] - sPoint[2]) * dt + (tPoint[2] - 2 * mPoint[2] + sPoint[2]) * dt ^ 2,
            sPoint[3] + 2 * (mPoint[3] - sPoint[3]) * dt + (tPoint[3] - 2 * mPoint[3] + sPoint[3]) * dt ^ 2,
        }
        if (hrect.isBorderCamera(nPoint[1], nPoint[2])) then
            curTimer.destroy()
            _missileEnding(false, options, cPoint)
            return
        end
        cPoint = nPoint
        if (type(options.onMove) == "function") then
            local mRes = options.onMove(options, cPoint)
            if (mRes == false) then
                curTimer.destroy()
                _missileEnding(false, options, cPoint)
                return
            end
        end
        fac = math.angle(cPoint[1], cPoint[2], tPoint[1], tPoint[2])
        distanceCur = math.distance(cPoint[1], cPoint[2], tPoint[1], tPoint[2])
        rotateY = rotateY - dtRot * di
        if (math.distance(oriX, oriY, cPoint[1], cPoint[2]) > 2000) then
            hjapi.EXSetEffectZ(options.arrowToken, -9999)
            hjapi.EXSetEffectSize(options.arrowToken, 0.01)
            cj.DestroyEffect(options.arrowToken)
            options.arrowToken = cj.AddSpecialEffect(options.model, cPoint[1], cPoint[2])
            hjapi.EXSetEffectSize(options.arrowToken, 0.01)
            hjapi.EXEffectMatRotateZ(options.arrowToken, fac)
            hjapi.EXEffectMatRotateY(options.arrowToken, rotateY)
            oriX, oriY = cPoint[1], cPoint[2]
        else
            hjapi.EXSetEffectSize(options.arrowToken, options.scale)
            hjapi.EXSetEffectXY(options.arrowToken, cPoint[1], cPoint[2])
            hjapi.EXEffectMatRotateZ(options.arrowToken, fac - fac0)
            hjapi.EXEffectMatRotateY(options.arrowToken, -dtRot * di)
        end
        hjapi.EXSetEffectZ(options.arrowToken, cPoint[3])
        fac0 = fac
        if (distanceCur > collision and distancePrev ~= nil) then
            if ((distanceCur - distancePrev) > faraway) then
                curTimer.destroy()
                _missileEnding(false, options, cPoint)
                return
            end
        end
        distancePrev = distanceCur
        if (dt >= 1 or distanceCur <= collision) then
            curTimer.destroy()
            _missileEnding(true, options, tPoint)
        end
    end)
end

SKILL = function()
    ---@param evtData onSkillEffectData
    hevent.reaction(CONST_EVENT.skillEffect, "skills", function(evtData)
        local name = hslk.i2v(evtData.triggerSkill, "slk", "Name")
        if (type(SKILLS[name]) == "function") then
            SKILLS[name](evtData)
        end
    end)
end