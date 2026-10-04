gKateStates = {}
for i = 0, MAX_PLAYERS - 1 do
    gKateStates[i] = {
        squishScale = 1,
        setGroundScale = false,
        velYBurst = 0,
        velYFastfall = 20,
        thokCount = 1,
        fillStep = false,
        gfxSpin = 0
    }
end

function lerp_s16(a, b, t)
    a = math.s16(math.round(a))
    b = math.s16(math.round(b))

    local delta = b - a

    if delta > 0x8000 then
        delta = delta - 0x10000
    elseif delta < -0x8000 then
        delta = delta + 0x10000
    end

    return math.s16(a + delta * t)
end

local ACT_KATE_THOK = allocate_mario_action(ACT_GROUP_AIRBORNE)

---@param m MarioState
local function act_kate_thok(m)
    local e = gKateStates[m.playerIndex]
    set_mario_animation(m, MARIO_ANIM_DIVE)
    if m.actionState == 0 then
        m.vel.y = 10
        m.forwardVel = m.forwardVel + 30
        m.vel.x = sins(m.faceAngle.y)*m.forwardVel
        m.vel.z = coss(m.faceAngle.y)*m.forwardVel
        m.actionState = m.actionState + 1
    end

    local step = perform_air_step(m, AIR_STEP_CHECK_LEDGE_GRAB)
    if step == AIR_STEP_LANDED then
        return set_mario_action(m, ACT_JUMP_LAND, 0)
    elseif step == AIR_STEP_HIT_WALL then
        local prevAngle = m.faceAngle.y
        mario_bonk_reflection(m, 0)
        set_mario_action(m, ACT_DOUBLE_JUMP, 0)
        if m.controller.buttonDown & Z_TRIG ~= 0 then
            e.gfxSpin = (m.faceAngle.y - prevAngle) - 0x20000
            m.vel.y = -m.forwardVel
        else
            e.gfxSpin = (m.faceAngle.y - prevAngle) + 0x20000
            m.vel.y = m.forwardVel
        end
        m.forwardVel = 0
    end
end

hook_mario_action(ACT_KATE_THOK, act_kate_thok, INT_KICK)

---@param m MarioState
local function kate_update(m)
    local e = gKateStates[m.playerIndex]
    if e.velYBurst ~= 0 then
        m.vel.y = m.vel.y*e.velYBurst
        e.velYBurst = 0
    end

    if m.action & ACT_FLAG_AIR ~= 0 then
        if m.controller.buttonDown & Z_TRIG ~= 0 then
            e.velYFastfall = math.min(m.vel.y, e.velYFastfall) - 6
            m.vel.y = e.velYFastfall
        end

        e.squishScale = math.clamp(math.lerp(e.squishScale, 1 + (math.abs(m.vel.y) - 10)*0.01, 0.3), 0.2, 1.8)
        if m.vel.y > 0 then
            m.marioObj.header.gfx.pos.y = m.pos.y - 160*(e.squishScale - 1)
        end
        e.setGroundScale = false
    else
        e.velYFastfall = 20
        e.thokCount = 1
        if not e.setGroundScale then
            e.squishScale = 2 - e.squishScale
            e.setGroundScale = true
        end
        e.squishScale = math.lerp(e.squishScale, 1, 0.1)
    end
    
    if m.forwardVel > 75 then
        m.forwardVel = math.lerp(m.forwardVel, 75, 0.1)
    end

    obj_scale_xyz(m.marioObj, (2 - e.squishScale), e.squishScale, (2 - e.squishScale))

    if e.gfxSpin ~= 0 then
        e.gfxSpin = math.lerp(e.gfxSpin, 0, 0.2)
        e.gfxSpin = e.gfxSpin > 0 and math.floor(e.gfxSpin) or math.ceil(e.gfxSpin)
        m.marioObj.header.gfx.angle.y = m.faceAngle.y + e.gfxSpin
    end

    e.fillStep = false
    m.peakHeight = m.pos.y
end

---@param m MarioState
-- Prevent jitter on act cancel
local function act_cancel_gracefully(m)
    local e = gKateStates[m.playerIndex]
    if not e.fillStep then
        perform_air_step(m, 0)
        e.fillStep = true
    end
    return 1
end

local function kate_before_action(m, nextAct)
    local e = gKateStates[m.playerIndex]
    if nextAct & ACT_FLAG_AIR ~= 0 then
        e.velYBurst = math.abs(e.squishScale - 1) + 1
    end
    if nextAct == ACT_JUMP then
        return set_mario_action(m, ACT_DOUBLE_JUMP, 0)
    end
    if nextAct == ACT_DOUBLE_JUMP_LAND then
        return set_mario_action(m, ACT_JUMP_LAND, 0)
    end
    if nextAct == ACT_JUMP_KICK or nextAct == ACT_DIVE then
        return set_mario_action(m, ACT_KATE_THOK, 0)
    end
    if nextAct == ACT_GROUND_POUND then
        return act_cancel_gracefully(m)
    end
end

charSelect.character_hook_moveset(CT_KATE, HOOK_MARIO_UPDATE, kate_update)
charSelect.character_hook_moveset(CT_KATE, HOOK_BEFORE_SET_MARIO_ACTION, kate_before_action)