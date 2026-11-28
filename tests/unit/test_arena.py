"""Contract tests for Challenge Mode arena exit locks (adapters/eeex/arena.lua & runtime.lua)."""

import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


def _run_lua(backend: str, script: str):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path = ... .. '/?.lua;' .. package.path", ROOT.as_posix())
    return runtime.execute(script)


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_runtime_challenge_mode_cascade_and_overrides(backend):
    result = _run_lua(
        backend,
        """
        local runtime = require('adapters.eeex.runtime')
        local encounters = require('combat-intent.encounters')

        local function installWith(iniMap)
            local saved = {}
            local g = {
                Infinity_GetINIValue = function(sec, key, fallback)
                    if sec == 'BGSE' and iniMap[key] ~= nil then return iniMap[key] end
                    return fallback
                end,
                Infinity_SetINIValue = function(sec, key, val)
                    saved[key] = val
                end,
                BGSE_HOOKED = {},
            }
            local root = runtime.install(g, {director = false, choice = false})
            return root, root.inspect(), saved
        end

        local _, dflt = installWith({})
        assert(dflt.challengeMode == false)
        assert(dflt.arena.enabled == false)
        assert(dflt.ui.playerDefensiveContingencies == false)

        local root, chg, saved = installWith({ChallengeMode = 1})
        assert(chg.challengeMode == true)
        assert(chg.arena.enabled == true)
        assert(chg.ui.playerDefensiveContingencies == true)

        local _, noLocks = installWith({ChallengeMode = 1, ArenaLocks = 0})
        assert(noLocks.challengeMode == true and noLocks.arena.enabled == false)
        assert(noLocks.ui.playerDefensiveContingencies == true)

        local _, noFilter = installWith({ChallengeMode = 1, PlayerDefensiveContingencies = 0})
        assert(noFilter.challengeMode == true and noFilter.arena.enabled == true)
        assert(noFilter.ui.playerDefensiveContingencies == false)

        root.setChallengeMode(false, true)
        local off = root.inspect()
        assert(off.challengeMode == false and off.arena.enabled == false and off.ui.playerDefensiveContingencies == false)
        assert(saved.ChallengeMode == 0)

        root.setChallengeMode(true, true)
        local on = root.inspect()
        assert(on.challengeMode == true and on.arena.enabled == true and on.ui.playerDefensiveContingencies == true)
        assert(saved.ChallengeMode == 1)

        root.setArenaLocks(false, true)
        assert(root.inspect().arena.enabled == false and saved.ArenaLocks == 0)
        assert(encounters.arenaLocks().BG0615 ~= nil)
        return true
        """,
    )
    assert result is True


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_arena_lock_unlock_duplicates_bit_preservation_and_callout(backend):
    result = _run_lua(
        backend,
        """
        local arena = require('adapters.eeex.arena')
        local encounters = require('combat-intent.encounters')

        local objects, vars, mem = {}, {}, {}
        local combatActive, seeActive, engineOn, shouts, gt, clockMs = false, false, true, 1, 100, 1000
        local writeFail = false
        local announced, freedFiles, evaledMenus, pushedMenus = {}, 0, {}, {}
        local menuCb, reloadCb, initCb, listsCb, destroyCb

        local function callable(fn)
            return setmetatable({}, {__call = function(_, ...) return fn(...) end})
        end

        local function makeTrigger(id, name, trigType, left, top, initialFlags, asCallable)
            local tok = {kind = 'entry', id = id}
            local base = id * 1000
            mem[base + 0x20] = initialFlags
            local getFn = function() return name end
            local trig
            local drawFn = function(self, arg)
                self.drawPolyCalls = self.drawPolyCalls + 1
                self.drawPolyArgs[#self.drawPolyArgs + 1] = arg
            end
            trig = {
                m_id = id,
                m_objectType = 0x41,
                m_triggerType = trigType,
                m_scriptName = {get = asCallable and callable(getFn) or getFn},
                m_rBounding = {left = left, top = top},
                m_newEntryPoint = tok,
                _base = base,
                drawPolyCalls = 0,
                drawPolyArgs = {},
                SetDrawPoly = asCallable and callable(drawFn) or drawFn,
            }
            objects[id] = trig
            return trig
        end

        local function makeSprite(id, ea, state, hp, active)
            local sp = {
                m_id = id,
                m_objectType = 0x31,
                m_active = active == nil and 1 or active,
                m_typeAI = {m_EnemyAlly = ea},
                m_baseStats = {m_generalState = state, m_hitPoints = hp},
            }
            objects[id] = sp
            return sp
        end

        local t1 = makeTrigger(101, 'Door0614\\0oint 1', 2, 152, 409, 0x0, true)
        local t2 = makeTrigger(102, 'Door0614\\0oint 2', 2, 739, 173, 0x100, false)
        local t3 = makeTrigger(103, 'Door0621', 2, 331, 271, 0x4, false)
        local nonTravel = makeTrigger(104, 'Door0614', 1, 10, 20, 0x0, false)
        local foe = makeSprite(201, 255, 0, 30, 1)
        local pc = makeSprite(301, 2, 0, 50, 1)

        local area = {
            m_resref = {get = callable(function() return 'BG0615\\0\\0' end)},
            m_lVertSortBack = {101, 102, 104},
            m_lVertSort = {103, 201, 301},
        }
        pc.m_pArea = area

        local g = {
            CGameObjectType = {TRIGGER = 0x41},
            EEex_EngineGlobal_CBaldurChitin = {m_pObjectGame = {m_worldTime = {m_gameTime = gt}}},
            Infinity_GetClockTicks = function() return clockMs end,
            EEex_Area_GetVisible = function() return area end,
            EEex_Area_GetVariableInt = function(_, key) return vars[key] or 0 end,
            EEex_Area_SetVariableInt = function(_, key, val) vars[key] = val end,
            EEex_Utility_IterateCPtrList = function(list, fn)
                for _, id in ipairs(list) do fn(id) end
            end,
            EEex_GameObject_Get = function(id) return objects[id] end,
            EEex_GameObject_CastUserType = function(o) return o end,
            EEex_GameObject_IsSprite = function(o) return o.m_objectType == 0x31 end,
            EEex_Sprite_GetInPortrait = function(slot) return slot == 0 and pc or nil end,
            EEex_UDToPtr = function(tok) return objects[tok.id]._base end,
            EEex_ReadU32 = function(addr) return mem[addr] end,
            EEex_Write32 = function(addr, val)
                if writeFail then error('write blocked') end
                mem[addr] = val
            end,
            EEex_BAnd = function(a, b)
                local res, bit = 0, 1
                while a > 0 and b > 0 do
                    if a % 2 == 1 and b % 2 == 1 then res = res + bit end
                    a, b, bit = math.floor(a / 2), math.floor(b / 2), bit * 2
                end
                return res
            end,
            EEex_Trigger_ParseConditionalString = function(s)
                assert(s == 'CombatCounterGT(0)' or s == 'See([EVILCUTOFF])')
                return {kind = s, free = function() freedFiles = freedFiles + 1 end}
            end,
            EEex_Trigger_EvalScriptFileConditionalAsAIBase = function(file)
                if file.kind == 'CombatCounterGT(0)' then return combatActive end
                if file.kind == 'See([EVILCUTOFF])' then return seeActive end
                return false
            end,
            Infinity_GetINIValue = function(_, key, dflt)
                if key == 'Shouts' then return shouts end
                return dflt
            end,
            BGSE_CALL_STRREFS = {arena_locked = 9001},
            EEex_Sprite_DisplayTextRef = function(sp, ref, opts)
                announced[#announced + 1] = {id = sp.m_id, ref = ref, overHead = opts and opts.overHead}
            end,
            EEex_Menu_AddAfterMainFileLoadedListener = function(fn) menuCb = fn end,
            EEex_Menu_AddAfterMainFileReloadedListener = function(fn) reloadCb = fn end,
            EEex_GameState_AddInitializedListener = function(fn) initCb = fn end,
            EEex_Opcode_AddDeferredListsResolvedListener = function(fn) listsCb = fn end,
            EEex_GameState_AddDestroyedListener = function(fn) destroyCb = fn end,
            EEex_Menu_Eval = function(src) evaledMenus[#evaledMenus + 1] = src end,
            Infinity_PushMenu = function(name) pushedMenus[#pushedMenus + 1] = name end,
        }

        local function setTick(t)
            gt = t
            g.EEex_EngineGlobal_CBaldurChitin.m_pObjectGame.m_worldTime.m_gameTime = t
        end

        local inst = arena.new(g, {
            enabled = true,
            locks = encounters.arenaLocks(),
            isEnabled = function() return engineOn end,
        })

        -- Menu, reload, deferred-lists & GameState lifecycle listeners push BGSE_ARENA_TICK and run fastStep().
        assert(type(menuCb) == 'function' and type(reloadCb) == 'function'
            and type(initCb) == 'function' and type(listsCb) == 'function' and type(destroyCb) == 'function')
        menuCb()
        assert(#evaledMenus == 1 and evaledMenus[1]:find('BGSE_ARENA_TICK', 1, true) and #pushedMenus == 0)
        initCb()
        assert(#pushedMenus == 1 and pushedMenus[1] == 'BGSE_ARENA_TICK' and g._bgseArenaInitSeen == true)
        reloadCb()
        assert(#pushedMenus == 2 and pushedMenus[2] == 'BGSE_ARENA_TICK')

        -- Outside combat: triggers remain unlocked; same-tick listsCb call within 20ms is rate-limited.
        g.BGSE_Arena_Tick()
        assert(mem[t1._base + 0x20] == 0x0 and mem[t2._base + 0x20] == 0x100 and mem[t3._base + 0x20] == 0x4)
        assert(inst:inspect().counts.locked == 0 and inst:inspect().lastError == false)
        assert(inst:inspect().lastArea == 'BG0615' and inst:inspect().lastHostiles == 1 and inst:inspect().lastCombat == false)
        local ticksAtMs1000 = inst:inspect().counts.ticks
        clockMs = 1010
        listsCb()
        assert(inst:inspect().counts.ticks == ticksAtMs1000)
        clockMs = 1025
        listsCb()
        assert(inst:inspect().counts.ticks == ticksAtMs1000 + 1)

        -- Combat begins: lock Door0614#1 (0->0x100, var=1), Door0614#2 (keep 0x100, var=2), Door0621 (0x4->0x104, var=1).
        combatActive = true
        setTick(101)
        inst:step()
        assert(mem[t1._base + 0x20] == 0x100 and t1.drawPolyCalls == 1 and t1.drawPolyArgs[1] == 0)
        assert(mem[t2._base + 0x20] == 0x100 and t2.drawPolyCalls == 0)
        assert(mem[t3._base + 0x20] == 0x104 and t3.drawPolyCalls == 1 and t3.drawPolyArgs[1] == 0)
        assert(mem[nonTravel._base + 0x20] == 0x0)
        assert(vars.BGSE_LK_DOOR0614_152_409_1 == 1)
        assert(vars.BGSE_LK_DOOR0614_739_173_2 == 2)
        assert(vars.BGSE_LK_DOOR0621_331_271_1 == 1)
        assert(#announced == 1 and announced[1].ref == 9001 and announced[1].overHead == true)
        assert(inst:inspect().counts.locked == 3 and inst:inspect().lastCombat == true)

        -- Same tick short-circuits cleanly without duplicate work.
        local ticksBefore = inst:inspect().counts.ticks
        inst:step()
        assert(inst:inspect().counts.ticks == ticksBefore + 1 and #announced == 1)

        -- Sleeping living hostile in m_lVertSortBack keeps triggers locked even when front list has no living foes.
        combatActive = false
        foe.m_typeAI.m_EnemyAlly = 254
        local sleeper = makeSprite(205, 255, 0x20, 12, 1)
        area.m_lVertSortBack = {101, 102, 104, 205}
        setTick(102)
        inst:step()
        assert(mem[t1._base + 0x20] == 0x100 and mem[t3._base + 0x20] == 0x104 and #announced == 1)
        assert(inst:inspect().lastHostiles == 1)

        -- Charmed PC (254), inactive (m_active=0), HP=0, and dead state (0x800) do not count as living hostiles.
        sleeper.m_baseStats.m_generalState = 0x800
        local dead = makeSprite(202, 255, 0x800, 10, 1)
        local inactive = makeSprite(203, 255, 0, 10, 0)
        local zeroHp = makeSprite(204, 255, 0, 0, 1)
        area.m_lVertSort = {103, 201, 202, 203, 204, 301}
        setTick(103)
        inst:step()

        -- Living hostiles == 0: immediate unlock restores only var==1 triggers (SetDrawPoly(1)), keeps pre-existing var==2!
        assert(mem[t1._base + 0x20] == 0x0 and t1.drawPolyCalls == 2 and t1.drawPolyArgs[2] == 1)
        assert(mem[t2._base + 0x20] == 0x100 and t2.drawPolyCalls == 0)
        assert(mem[t3._base + 0x20] == 0x4 and t3.drawPolyCalls == 2 and t3.drawPolyArgs[2] == 1)
        assert(vars.BGSE_LK_DOOR0614_152_409_1 == 0)
        assert(vars.BGSE_LK_DOOR0614_739_173_2 == 0)
        assert(vars.BGSE_LK_DOOR0621_331_271_1 == 0)
        assert(inst:inspect().counts.unlocked == 3 and inst:inspect().lastHostiles == 0)

        -- See([EVILCUTOFF]) locks immediately even when CombatCounterGT(0) is still false; failed write rolls back var.
        foe.m_typeAI.m_EnemyAlly = 255
        combatActive = false
        seeActive = true
        writeFail = true
        setTick(104)
        inst:step()
        assert(mem[t1._base + 0x20] == 0x0 and vars.BGSE_LK_DOOR0614_152_409_1 == 0)
        writeFail = false
        setTick(105)
        inst:step()
        assert(mem[t1._base + 0x20] == 0x100 and mem[t3._base + 0x20] == 0x104 and #announced == 3)

        -- setEnabled(false) unlocks immediately on call without waiting for the next tick!
        seeActive = false
        inst:setEnabled(false)
        assert(mem[t1._base + 0x20] == 0x0 and mem[t3._base + 0x20] == 0x4 and inst:inspect().counts.unlocked == 6)

        -- Disabled fastStep skips after checking area once; turn back on via setEnabled(true) locks immediately.
        local ticksOff = inst:inspect().counts.ticks
        clockMs = 1100
        g.BGSE_Arena_Tick()
        assert(inst:inspect().counts.ticks == ticksOff)
        combatActive = true
        inst:setEnabled(true)
        assert(mem[t1._base + 0x20] == 0x100 and #announced == 4)

        -- Engine gate off also unlocks a locked arena immediately.
        engineOn = false
        setTick(107)
        inst:step()
        assert(mem[t1._base + 0x20] == 0x0 and mem[t3._base + 0x20] == 0x4)

        -- Game destroyed listener invalidates state, frees both trigger handles, and keeps _bgseArenaInitSeen true.
        assert(freedFiles == 0)
        destroyCb()
        assert(freedFiles == 2 and g._bgseArenaInitSeen == true)

        -- Error inside step() is contained by guardedStep() and surfaced in inspect().lastError.
        local origVisible = g.EEex_Area_GetVisible
        local badArea = setmetatable({}, {__index = function() error('area read fault') end})
        g.EEex_Area_GetVisible = function() return badArea end
        engineOn = true
        inst:invalidate()
        clockMs = 1200
        g.BGSE_Arena_Tick()
        assert(type(inst:inspect().lastError) == 'string' and inst:inspect().lastError:find('area read fault', 1, true))
        g.EEex_Area_GetVisible = origVisible

        -- Reload recovery: fresh instance sees saved vars from before load, even when reloading reset
        -- runtime trigger flags (0x100 cleared back to 0x0 / 0x4 on .ARE reload): var==1 re-applies
        -- bit 0x100 + SetDrawPoly(0) without touching var==2, counts.locked, or re-announcing.
        combatActive = false
        seeActive = false
        mem[t1._base + 0x20] = 0x0
        mem[t2._base + 0x20] = 0x0
        mem[t3._base + 0x20] = 0x4
        vars.BGSE_LK_DOOR0614_152_409_1 = 1
        vars.BGSE_LK_DOOR0614_739_173_2 = 2
        vars.BGSE_LK_DOOR0621_331_271_1 = 1
        -- Also exercise EEex_Area_GetVisible returning nil -> fallback to portrait 0 m_pArea.
        g.EEex_Area_GetVisible = function() return nil end
        local reloaded = arena.new(g, {
            enabled = true,
            locks = encounters.arenaLocks(),
            isEnabled = function() return engineOn end,
        })
        -- With living hostile still present on reload, write failure skips SetDrawPoly(0); retrying
        -- succeeds and restores var==1 trigger flags without touching var==2, counts.locked, or announcing.
        local shoutsBeforeReload = #announced
        local t1PolyBefore, t2PolyBefore, t3PolyBefore = t1.drawPolyCalls, t2.drawPolyCalls, t3.drawPolyCalls
        writeFail = true
        setTick(1075)
        reloaded:step()
        assert(mem[t1._base + 0x20] == 0x0 and mem[t3._base + 0x20] == 0x4)
        assert(t1.drawPolyCalls == t1PolyBefore and t3.drawPolyCalls == t3PolyBefore)
        writeFail = false
        setTick(108)
        reloaded:step()
        assert(mem[t1._base + 0x20] == 0x100 and mem[t2._base + 0x20] == 0x0 and mem[t3._base + 0x20] == 0x104)
        assert(t1.drawPolyCalls == t1PolyBefore + 1 and t1.drawPolyArgs[t1.drawPolyCalls] == 0)
        assert(t2.drawPolyCalls == t2PolyBefore)
        assert(t3.drawPolyCalls == t3PolyBefore + 1 and t3.drawPolyArgs[t3.drawPolyCalls] == 0)
        assert(#announced == shoutsBeforeReload and reloaded:inspect().counts.locked == 0)
        assert(reloaded:inspect().lastError == false)
        -- Subsequent living-hostile ticks see 0x100 already restored and do not re-call SetDrawPoly(0).
        setTick(109)
        reloaded:step()
        assert(t1.drawPolyCalls == t1PolyBefore + 1 and t3.drawPolyCalls == t3PolyBefore + 1)
        -- Restore t2 pre-existing 0x100 and kill hostiles before testing unlock on next tick!
        mem[t2._base + 0x20] = 0x100
        foe.m_baseStats.m_hitPoints = 0
        setTick(110)
        reloaded:step()
        assert(mem[t1._base + 0x20] == 0x0 and mem[t2._base + 0x20] == 0x100 and mem[t3._base + 0x20] == 0x4)
        assert(vars.BGSE_LK_DOOR0614_152_409_1 == 0 and vars.BGSE_LK_DOOR0621_331_271_1 == 0)

        -- Non-arena area clears checkPending so disabled fastStep only inspects once on area change.
        reloaded:setEnabled(false)
        area.m_resref = {get = callable(function() return 'BG2300\\0\\0' end)}
        reloaded:invalidate()
        clockMs = 1300
        g.BGSE_Arena_Tick()
        local nonArenaTicks = reloaded:inspect().counts.ticks
        assert(reloaded:inspect().lastArea == 'BG2300')
        clockMs = 1350
        g.BGSE_Arena_Tick()
        assert(reloaded:inspect().counts.ticks == nonArenaTicks)

        return true
        """,
    )
    assert result is True


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_runtime_install_destroy_and_reinstall_arena_listeners(backend):
    result = _run_lua(
        backend,
        """
        local runtime = require('adapters.eeex.runtime')
        local menuCbs, reloadCbs, initCbs, listsCbs, destroyCbs, pushed, freed = {}, {}, {}, {}, {}, {}, 0
        local vars, flags, combatOn, gt = {}, 0, false, 10
        local t1 = {
            m_objectType = 0x41,
            m_triggerType = 2,
            m_scriptName = { get = function() return 'Door2100' end },
            m_rBounding = { left = 10, top = 20 },
            m_newEntryPoint = {},
        }
        local foe = {
            m_typeAI = { m_EnemyAlly = 255 },
            m_baseStats = { m_generalState = 0, m_hitPoints = 10 },
        }
        local area = {
            m_resref = { get = function() return 'BG2101' end },
            m_lVertSort = { 1, 2 },
            m_lVertSortBack = {},
        }
        local pc = { m_pArea = area, m_baseStats = { m_generalState = 0, m_hitPoints = 20 } }
        local g = {
            BGSE_HOOKED = {},
            CGameObjectType = { TRIGGER = 0x41 },
            Infinity_GetINIValue = function(sec, key, fallback)
                if sec == 'BGSE' and key == 'ArenaLocks' then return 1 end
                return fallback
            end,
            EEex_Menu_AddAfterMainFileLoadedListener = function(fn) menuCbs[#menuCbs + 1] = fn end,
            EEex_Menu_AddAfterMainFileReloadedListener = function(fn) reloadCbs[#reloadCbs + 1] = fn end,
            EEex_Menu_Eval = function() end,
            EEex_GameState_AddInitializedListener = function(fn) initCbs[#initCbs + 1] = fn end,
            EEex_Opcode_AddDeferredListsResolvedListener = function(fn) listsCbs[#listsCbs + 1] = fn end,
            EEex_GameState_AddDestroyedListener = function(fn) destroyCbs[#destroyCbs + 1] = fn end,
            Infinity_PushMenu = function(name) pushed[#pushed + 1] = name end,
            EEex_Area_GetVisible = function() return area end,
            EEex_Utility_IterateCPtrList = function(list, fn)
                for _, v in ipairs(list) do
                    if fn(v) then break end
                end
            end,
            EEex_GameObject_Get = function(id) return id == 1 and t1 or foe end,
            EEex_GameObject_IsSprite = function(o) return o == foe end,
            EEex_Sprite_GetInPortrait = function(i) return i == 0 and pc or nil end,
            EEex_Area_GetVariableInt = function(_, key) return vars[key] or 0 end,
            EEex_Area_SetVariableInt = function(_, key, val) vars[key] = val end,
            EEex_UDToPtr = function() return 1000 end,
            EEex_ReadU32 = function() return flags end,
            EEex_Write32 = function(_, val) flags = val end,
            EEex_Trigger_ParseConditionalString = function()
                return { free = function() freed = freed + 1 end }
            end,
            EEex_Trigger_EvalScriptFileConditionalAsAIBase = function() return combatOn end,
            EEex_EngineGlobal_CBaldurChitin = { m_pObjectGame = { m_worldTime = { m_gameTime = gt } } },
        }

        local root1 = runtime.install(g, {director = false, choice = false})
        assert(#destroyCbs == 1 and #menuCbs == 2 and #reloadCbs == 1 and #initCbs == 1 and #listsCbs == 1)
        for _, fn in ipairs(menuCbs) do fn() end
        assert(#pushed == 0)
        initCbs[1]()
        assert(#pushed == 1 and pushed[1] == 'BGSE_ARENA_TICK')
        reloadCbs[1]()
        assert(#pushed == 2 and pushed[2] == 'BGSE_ARENA_TICK')
        listsCbs[1]()
        destroyCbs[1]()
        assert(freed == 2 and g._bgseArenaInitSeen == true and g._bgseArenaMenuLoaded == true)

        -- Second install on the same global table updates current arena and respects menu/init/reload state.
        initCbs[1]()
        assert(#pushed == 3)
        local root2 = runtime.install(g, {director = false, choice = false})
        assert(root2.arena ~= root1.arena)
        assert(#pushed == 4 and #destroyCbs == 1 and #initCbs == 1 and #listsCbs == 1)
        combatOn = true
        gt = 11
        g.EEex_EngineGlobal_CBaldurChitin.m_pObjectGame.m_worldTime.m_gameTime = gt
        listsCbs[1]()
        assert(flags == 0x100 and vars.BGSE_LK_DOOR2100_10_20_1 == 1)

        -- runtime.setEnabled(false) unlocks immediately without waiting for another tick!
        root2.setEnabled(false)
        assert(flags == 0x0 and vars.BGSE_LK_DOOR2100_10_20_1 == 0)

        root2.setEnabled(true)
        assert(flags == 0x100 and vars.BGSE_LK_DOOR2100_10_20_1 == 1)

        destroyCbs[1]()
        assert(freed == 4 and g._bgseArenaInitSeen == true)

        return true
        """,
    )
    assert result is True
