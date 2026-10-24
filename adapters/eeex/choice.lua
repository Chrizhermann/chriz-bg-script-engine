-- EEex side of the engine's own choice (step 3, second and third slices). When a hooked mage's or
-- priest's script asks the gate and SCS's round timer has run out, this reads what the
-- creature perceives (sense.lua, with the details SCS's scripts read), what it has ready
-- (creature.lua, classified by combat-intent/spells.lua), the engine's answers to those spells'
-- own SPLPROT checks for each enemy (sense.splprot) and the director's plan, and asks
-- combat-intent/choice.lua for an attack. A chosen attack becomes the gate's decision: a
-- normal SpellRES or SpellPointRES that first sets SCS's round timer as SCS's own cast blocks
-- do, so SCS's filler runs between casts. Right before the response is queued the target is
-- checked again and named through EEex's EEex_Target object, which reads the caster's own
-- table, so no other creature's choice can change it. A cast that never starts is given up;
-- one that ends with no effect on its target is remembered as a miss, judged only once the
-- target could react (not while another creature's Time Stop freezes it). No answer, an error
-- or a switch leaves the round to SCS. Session-local; a load forgets it all.
--
-- Since the third slice the choice weighs the caster's protections and buffs against its attacks
-- (combat-intent/defence.lua): the frame then also carries what protects each friend now and the
-- weapons around (sense.defend). A defence is cast on the caster (SpellRES at Myself), at a point
-- or at an ally the profile names. A defence the creature starts, the engine's or its script's,
-- starts the pause before the next one, as SCS's redefend timer does; a finished one is judged
-- by whether its friends carry its effects.
--
-- Openers (D2a): the choice also learns who holds a running Time Stop and the seconds left, and
-- whether the caster's Improved Alacrity runs. In the caster's own stop it learns what the
-- casts it started in the stop will do when time resumes (their kind, targets and expected
-- damage); the list is dropped when the stop ends.
--
-- Releases (D2b): a sequencer or trigger goes off with ForceSpellRES (at a point
-- ForceSpellPointRES), as SCS's own releases do: SpellRES would walk to the wrong range SCS
-- writes into it (batch G3).
--
-- Touch charges (D2c): a touch spell is cast like a defence, on the caster. The charge it puts in
-- the magic weapon slot is found by the item there, read as the touch weapon of a spell the
-- caster has memorized (at its level) or else as the item itself, and goes to the choice with
-- the caster's THAC0. A strike is AttackOneRound at EEex_Target after SCS's round timer; the
-- creature is held while it swings or the timer runs, so SCS's own touch block does not take the
-- charge elsewhere. Once the charge is gone the strike is judged: did its target lose hit points,
-- become disabled or carry an effect of the strike. A charge spent without effect is a miss of its
-- touch spell on that enemy, as a cast that left its target untouched is.
--
-- Weapon attacks (D2c): the choice also gets the weapon in the caster's hand (sense.attack, with
-- what its hit casts or applies, classified), its attacks a round and whether the magic weapon
-- slot is taken. A weapon attack is AttackOneRound at EEex_Target after SCS's round timer, like
-- a strike; the creature is held while it attacks, or while the timer runs and its target lives,
-- and then whether its target lost hit points is recorded. A spell that conjures a weapon is cast
-- on the caster.
--
-- Healing and curing (D3a, D3b): a heal or cure is cast on the caster, at an ally (sanctuary does
-- not keep it out) or at a point; a potion is drunk with UseItem. Like a disable, it claims the
-- allies it helps in the group as soon as it is chosen, so that another member leaves them to it.
-- Once it ends it is judged by whether a friend it was for gained hit points or lost a disabling
-- condition.
--
-- Summons (D3c): the choice also gets each creature the caster's ready summoning spells name, as
-- combat-intent/summons.lua profiles it from its CRE file, the weapon in its first weapon slot and
-- the ammunition in its first filled quiver slot (read once per creature). A summons is cast at a
-- point, on the caster or at an enemy; once it ends it is judged by whether allies the caster did
-- not see before now stand in its view: creatures of the files the spell names, or, for a spell that
-- also brings creatures from monster tables, summoned creatures (GENDER.IDS).
--
-- Protection removal (D3d): when a ready spell removes something from enemies, the choice also gets
-- each enemy's active effects (sense.wards), each classified on its own and cached by its fields. A
-- removal is cast at an enemy, a point or on the caster; once it ends it is judged by whether an
-- enemy it was for lost effects, skins, images or its invisibility, or is gone.
--
-- Danger zones (D3e): the choice also gets the zones in the caster's area (sense.zones, read once a
-- tick for each area), each classified once by what one explosion delivers, with who cast it and
-- its own saves, resistances, protections and SPLPROT marks for those spells, and whether it is
-- webbed or entangled. A way out is MoveToPoint to the nearest open spot (EEex's search map) that
-- still lies outside the zones it leaves, without SCS's round timer, so the engine decides again
-- once the creature is out; it is held while it walks, and judged by whether it got out. While SCS's
-- round timer runs, and when the creature sees no enemy, the engine still leads it out of a zone
-- that hurts it, unless it is casting. BGSE_Zones (api:zones) tells SCS's own cloud blocks above
-- the hook (escapes, runs from a marker and stand-still; bgse/lib/hook.tpa) to stand aside while
-- the engine weighs zones for the creature.
--
-- Wit (combat-intent/mind.lua, MIND-01): each creature's profile is the default one with its wit,
-- from its INT and WIS, its IDS values, its family, its creature file (overrides) and the game's
-- difficulty, worked out again only when one of them changes; a 'wit' row logs it. A dull creature
-- sees no zone until it hurts: each time its hit points have dropped since it was last looked at
-- while a zone hurts it where it stands, it draws once whether the pain drives it out
-- (zones.painChance); then it leaves until it is out. SCS's cloud blocks stand aside for a dull
-- creature meanwhile, so it stays and fights. A creature in one of the game's rage states counts
-- as raging.
local sense=require('adapters.eeex.sense')
local creature=require('adapters.eeex.creature')
local resources=require('adapters.eeex.resources')
local directors=require('adapters.eeex.director')
local spells=require('combat-intent.spells')
local targeting=require('combat-intent.targeting')
local defence=require('combat-intent.defence')
local weapons=require('combat-intent.weapons')
local choice=require('combat-intent.choice')
local summons=require('combat-intent.summons')
local zones=require('combat-intent.zones')
local mind=require('combat-intent.mind')
local rngs=require('kernel.rng')
local M={}
M.families={mage=true,priest=true}
-- Game ticks (15 a second). A queued cast that has not started pendingTicks after it was
-- queued, or after the creature's casting aura was last seen busy, is given up; a started one is
-- held as long beyond its casting time (decide). outcomeTicks after a cast ends, or after time
-- resumes if a Time Stop froze the target, its effect on the target is judged.
M.pendingTicks=45
M.outcomeTicks=30
-- A started cast that ends this much before its casting time was interrupted.
M.interruptSlack=3
-- The name under which the caster's EEex_Target table holds the engine's target.
M.targetName='BGSE'
-- SCS's round timer, set the way SCS's own cast blocks set it.
M.timer='castspell'
M.setTimer='SetGlobalTimer("castspell","LOCALS",ONE_ROUND)'
M.cacheLimit=1024
M.logCapacity=128
M.judgeLimit=64
-- Item slots a creature drinks from: the quick items and the backpack (SLOTS.IDS).
M.itemFirst,M.itemLast=15,33
-- Casts of the engine's own: Spell (SpellRES) and SpellPoint (SpellPointRES); ForceSpell and
-- ForceSpellPoint (ForceSpellRES, ForceSpellPointRES) for releases; UseItem for a potion. Each
-- holds the spell's or item's resref as its first string.
M.CASTS={[31]=true,[95]=true,[113]=true,[114]=true,[34]=true}
M.USE=34
-- Decisions for friends: sanctuary keeps out enemies' casts, not these; heals and cures claim the
-- allies they help.
M.FRIENDLY={defence=true,heal=true,cure=true}
M.CARE={heal=true,cure=true}
-- STATE.IDS bits of the conditions a cure takes away (combat-intent/care.lua): sleeping,
-- berserk, panic, stunned, silenced, poisoned, blind, diseased, feebleminded, confused.
M.CONDITION_BITS={0x1,0x2,0x4,0x8,0x1000,0x4000,0x40000,0x80000,0x100000,0x80000000}
-- Attack actions (ACTION.IDS): Attack, AttackNoSound, AttackOneRound, AttackReevaluate.
M.ATTACKS={[3]=true,[98]=true,[105]=true,[134]=true}
-- The magic weapon slot (SLOTS.IDS), where a spell's weapon goes, and how long the engine holds a
-- creature for one strike at most (two rounds).
M.magicSlot=34
M.strikeTicks=180
-- A CRE file's item slots (its own order, from 0): the first weapon slot and the quiver slots.
M.creWeapon=9
M.creQuiver={13,14,15}
M.required={'EEex_GameObject_Get','EEex_GameObject_IsSprite','EEex_Sprite_GetCastTimer',
    'EEex_Sprite_GetLocalInt','EEex_GetUDAux','EEex_Sprite_GetState','EEex_Sprite_GetStat'}
-- STATS.IDS: WIZARD_IMPROVED_ALACRITY, what SCS tests. Improved Alacrity (SPWI921, with and
-- without Spell Revisions, and SCS's DW#QALAC) sets it with opcode 282 p2=9. AURACLEANSING is
-- not used: an item could hold it for good.
M.alacrityStat=165
-- The game's Time Stop count falls by two a tick (learned.md, section 1): seconds = count/30.
M.stopCount=30
-- Wit: STATS.IDS INT and WIS; the game's own rage states in SPLSTATE.IDS, the same in every
-- install read: BLOOD_RAGE, ANIMAL_RAGE, BARBARIAN_RAGE, BERSERKER_RAGE, MINSC_BERSERK and
-- STATE_ENRAGED, which Barbarian Rage, the Berserker's Enrage and Minsc's Berserk all set as
-- well (SPCL152, SPCL321, SPIN117: opcode 328).
M.intStat=38
M.wisStat=39
M.rageStates={34,39,76,77,78,104}
-- Casts remembered per caster in its own Time Stop.
M.stopCastLimit=32
-- MoveToPoint (ACTION.IDS); a way out is held while the creature walks it, or for moveGrace ticks
-- until the walk starts, and for twice its seconds and a margin at most.
M.MOVE=23
M.moveGrace=8
M.moveMargin=30
-- Game ticks a second, for the projectile's counters (lab batch H measured 15.00).
M.ticksPerSecond=15
-- Ticks between two looks at what enemies do in the zones of an area (a third of a second; zones
-- explode a second or more apart).
M.lookTicks=5
-- The casting aura of a creature's last cast counts from 0 at the cast's start to about 99, then
-- reads -1 (docs/learned.md, section 2); a cast queued meanwhile starts casting when it frees.
M.auraTicks=100
-- What EEex must offer for zones to be read.
M.zoneRequired={'EEex_Projectile_GetType','EEex_CastUD'}
local UNSEEN=targeting.STATE.invisible+targeting.STATE.improvedInvisible

local function text(value) return (value:match('^[^%z]*'):upper()) end
local function valid(resref) return type(resref)=='string' and #resref>0 and #resref<=8 and not resref:find('[^A-Z0-9_#%-]') end
local function whole(v) return type(v)=='number' and v>=0 and v<65536 and v%1==0 end
-- A list of object ids as a set.
local function idSet(list)
    local out={}
    for _,id in ipairs(type(list)=='table' and list or {}) do out[id]=true end
    return out
end

-- Whether SCS's round timer is still running for sprite at tick. Game timers hold the game
-- time they run out at; without the accessor the timer counts as running, so the engine never
-- takes a round it cannot place.
function M.timerRunning(g,sprite,tick)
    local get=rawget(g,'EEex_Sprite_GetLocalInt')
    if type(get)~='function' then return true end
    local ok,value=pcall(get,sprite,M.timer)
    return ok and type(value)=='number' and value>tick
end

-- The response that casts decision's spell (a release with ForceSpellRES), or strikes with the
-- charge or attacks with the weapon in hand, or drinks the item, or nil.
function M.response(decision)
    if type(decision)~='table' or not valid(decision.resref) then return nil end
    if decision.use then
        if not decision.self then return nil end
        return M.setTimer..'\nUseItem("'..decision.resref..'",Myself)'
    end
    if decision.kind=='strike' or decision.kind=='weapon' then
        local t=decision.target
        if type(t)~='number' or t<0 or t%1~=0 then return nil end
        return M.setTimer..'\nAttackOneRound(EEex_Target("'..M.targetName..'"))'
    end
    -- A way out of a zone leaves SCS's round timer alone: the creature decides again once it is out.
    if decision.kind=='escape' then
        local p=decision.point
        if type(p)~='table' or not whole(p.x) or not whole(p.y) then return nil end
        return 'MoveToPoint(['..p.x..'.'..p.y..'])'
    end
    local cast=decision.release and 'ForceSpell' or 'Spell'
    if decision.point then
        local p=decision.point
        if not whole(p.x) or not whole(p.y) then return nil end
        return M.setTimer..'\n'..cast..'PointRES("'..decision.resref..'",['..p.x..'.'..p.y..'])'
    end
    if decision.self then return M.setTimer..'\n'..cast..'RES("'..decision.resref..'",Myself)' end
    local t=decision.target
    if type(t)=='number' and t>=0 and t%1==0 then
        return M.setTimer..'\n'..cast..'RES("'..decision.resref..'",EEex_Target("'..M.targetName..'"))'
    end
end

function M.new(g,options)
    options=options or {}
    local reader=options.reader or resources.new(g)
    local director=options.director
    local defaultMind=mind.new()
    -- mindFor(sprite, family): the creature's profile (wit, below), or options.mindFor's.
    local mindFor
    -- Wit: on unless options.wit is false; overrides by creature file (mind.wit); each creature's
    -- profile with the values it was made from (minds), rebuilt when the default changes (version).
    local witOn,witOverrides=options.wit~=false,options.witOverrides
    local minds,mindCount,mindVersion={},0,0
    -- hurts: each creature's hit points when last looked at for pain; pained: the tick the pain
    -- drove a dull creature out, until it is out.
    local hurts,hurtCount,pained={},0,{}
    local seed=options.seed
    if type(seed)~='number' then
        local clock=rawget(g,'os') and g.os.time or (os and os.time)
        seed=(clock and clock() or 1)%2147483645+1
    end
    local rng=rngs.new(seed)
    local enabled=options.enabled~=false
    local missing
    for _,name in ipairs(M.required) do
        if type(rawget(g,name))~='function' then missing=missing or name end
    end
    local cache,cached,items,itemCount={},0,{},0
    -- singles: single effects classified on their own (sense.wards), by their fields.
    local singles,singleCount={},0
    -- profiles: each summoned creature as a fighter, by resref (false when it cannot be read).
    local profiles,profileCount={},0
    local pending,running,judging,memory={},{},{},{}
    -- lastDefence: the tick each creature last started a defence; known: the creatures that
    -- asked the engine (hooked mages and priests); stopCasts: what the holder of the running
    -- Time Stop started in it.
    -- strikes: each creature's strike with a touch charge, until the charge is gone, or its
    -- weapon attack (weapon=true), until it is over.
    local lastDefence,known,stopCasts,strikes={},{},{},{}
    -- moves: each creature's way out of a zone while it walks it. zoneRead: the zones of an area
    -- read at a tick; zoneSpells: each zone's classification by object id (false when it cannot be
    -- classified); zoneBroken: zones could not be read at all this session.
    local moves,zoneRead,zoneSpells,zoneSpellCount,zoneBroken={},nil,{},0,false
    -- stays and insideOf: what the group has seen its enemies do in zones (look); lookedAt: the
    -- tick each area was last looked at.
    local stays,stayCount,insideOf,insideCount,lookedAt={},0,{},0,{}
    local counts={escapes=0,escaped=0,unescaped=0,zoneFailures=0,stayed=0,left=0,pains=0,witFailures=0,decisions=0,claims=0,declines=0,performed=0,skipped=0,started=0,lost=0,interrupted=0,
        hits=0,misses=0,errors=0,holds=0,frozen=0,marks=0,markFailures=0,defences=0,guarded=0,unguarded=0,
        guardFailures=0,openers=0,touches=0,strikes=0,strikeHits=0,strikeMisses=0,arms=0,attacks=0,attackHits=0,
        weaponFailures=0,releases=0,heals=0,cures=0,potions=0,cared=0,uncared=0,summons=0,conjured=0,
        unconjured=0,removals=0,stripped=0,unstripped=0,wardFailures=0}
    local reasons={}
    local log,nextRow,size={},1,0
    local root,sink,lastError,markError,guardError,weaponError,wardError,zoneError,witError
    -- trace: labs see every decline as a 'declined' row in the sink (never in the log).
    local trace,lastReason,lastDetail,lastCharge=false,nil,nil,nil
    local api={}

    local function now() return root and root.now and root.now() end
    local function record(row)
        log[nextRow]=row;nextRow=nextRow%M.logCapacity+1;size=math.min(size+1,M.logCapacity)
        if sink then pcall(sink,row) end
    end
    local function failed(where,err)
        counts.errors=counts.errors+1
        lastError=where..': '..tostring(err):sub(1,200)
        record({kind='error',where=where,error=tostring(err):sub(1,200)})
    end
    -- Wit (combat-intent/mind.lua): the game's difficulty (1 to 5), nil when it cannot be read.
    local function difficulty()
        local ok,value=pcall(function() return g.EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_options.m_nDifficultyLevel end)
        return ok and type(value)=='number' and value or nil
    end
    -- The creature's profile: the default as its family thinks, with its wit, made again when what it
    -- comes from changes.
    local function witted(sprite,family)
        if not witOn then return mind.forFamily(defaultMind,family) end
        local t=sprite.m_typeAI
        local c={int=g.EEex_Sprite_GetStat(sprite,M.intStat),wis=g.EEex_Sprite_GetStat(sprite,M.wisStat),
            general=t.m_General,race=t.m_Race,class=t.m_Class,family=family,resref=text(sprite.m_resref:get()),
            difficulty=difficulty()}
        local key=table.concat({tostring(c.int),tostring(c.wis),tostring(c.general),tostring(c.race),tostring(c.class),
            tostring(family),c.resref,tostring(c.difficulty),mindVersion},':')
        local had=minds[sprite.m_id]
        if had and had.key==key then return had.mind end
        local w=mind.wit(c,witOverrides)
        local made=mind.withWit(mind.forFamily(defaultMind,family),w)
        if not had then
            if mindCount>=M.cacheLimit then minds,mindCount={},0 end
            mindCount=mindCount+1
        end
        minds[sprite.m_id]={key=key,mind=made}
        record({kind='wit',tick=now(),member=sprite.m_id,resref=c.resref,family=family,step=w.step,danger=w.danger,
            int=w.int,wis=w.wis,from=w.from,difficulty=c.difficulty})
        return made
    end
    mindFor=options.mindFor or function(sprite,family)
        local ok,m=pcall(witted,sprite,family)
        if ok and type(m)=='table' then return m end
        counts.witFailures=counts.witFailures+1
        if not ok and not witError then
            witError=tostring(m):sub(1,200)
            record({kind='error',where='wit',error=witError})
        end
        return mind.forFamily(defaultMind,family)
    end
    local function decline(why)
        counts.declines=counts.declines+1
        reasons[why]=(reasons[why] or 0)+1
        lastReason=why
        return nil
    end
    local function get(id)
        local object=g.EEex_GameObject_Get(id)
        if object and g.EEex_GameObject_IsSprite(object,false) then return object end
    end
    -- The creature with id, dead or alive: a target that died still shows the hit points it lost.
    local function any(id)
        local object=g.EEex_GameObject_Get(id)
        if object and g.EEex_GameObject_IsSprite(object,true) then return object end
    end

    -- A spell at a caster level, classified once.
    local function classify(resref,level)
        local key=resref..':'..level
        if cache[key]==nil then
            if cached>=M.cacheLimit then cache,cached={},0 end
            local record=reader.get('SPL',resref)
            local index=record and spells.abilityForLevel(record,level)
            cache[key]=index and spells.classify(record,index,reader.lookup,{level=level}) or false
            cached=cached+1
        end
        return cache[key] or nil
    end
    -- A creature's active effects, classified as one record for what protects it (sense.guard).
    local function effectsOf(record) return spells.classify(record,1,reader.lookup,{level=1}) end
    -- One active effect on its own (sense.wards), classified once by its fields: its roles. A pause
    -- of six seconds or less on a creature itself is no role, so the key tells short from long.
    local function single(effect)
        local key=table.concat({effect.opcode,tostring(effect.p1),tostring(effect.p2),tostring(effect.timing),
            tostring(effect.res),tostring(effect.dice),tostring(effect.sides),tostring(effect.special),
            (type(effect.duration)=='number' and effect.duration>6) and 'L' or 'S'},':')
        local roles=singles[key]
        if roles==nil then
            if singleCount>=M.cacheLimit then singles,singleCount={},0 end
            local record={kind='SPL',resref='',name=0,flags=0,spellType=0,exclusion=0,school=0,secondary=0,level=1,
                casting={},abilities={{form=1,flags=0,location=2,target=5,targetCount=0,range=0,minLevel=1,speed=0,
                projectile=1,effects={effect}}}}
            local c=spells.classify(record,1,reader.lookup,{level=1})
            roles=type(c)=='table' and type(c.roles)=='table' and c.roles or {}
            singles[key]=roles;singleCount=singleCount+1
        end
        return roles
    end
    local function none() return {} end
    -- Whether a ready spell removes something from enemies.
    local function strips(rows)
        for _,row in ipairs(rows) do
            local r=type(row.spell)=='table' and type(row.spell.roles)=='table' and row.spell.roles.removal
            if type(r)=='table' and type(r.who)=='table' and (r.who.target or r.who.area) and
                type(row.ready)=='number' and row.ready>0 and row.usable then return true end
        end
        return false
    end
    -- What shows of a creature's protections: the count of its active effects, its skins, images
    -- and state.
    local function shown(object,tick)
        local ok,list=pcall(sense.wards,g,object,tick,none)
        local actor=sense.actor(g,object)
        return {effects=ok and #list or nil,skins=actor.skins,mirror=actor.mirror,state=actor.state}
    end
    -- An item's first three abilities, classified once.
    local function item(resref)
        if items[resref]==nil then
            if itemCount>=M.cacheLimit then items,itemCount={},0 end
            local record=reader.get('ITM',resref)
            local list={}
            if record and type(record.abilities)=='table' then
                for i=1,math.min(3,#record.abilities) do list[i]=spells.classify(record,i,reader.lookup,{level=1}) end
            end
            items[resref]=list;itemCount=itemCount+1
        end
        return items[resref]
    end
    -- The item in the creature's magic weapon slot, or nil.
    local function held(sprite)
        local ok,resref=pcall(function()
            local item=sprite.m_equipment.m_items:get(M.magicSlot)
            return item and text(item.cResRef:get()) or nil
        end)
        if ok and valid(resref) then return resref end
    end
    -- The touch charge the creature holds, or nil: the touch weapon of a spell it has memorized
    -- whose item is in its magic weapon slot (read at the caster's level), else that item read on
    -- its own when its first ability is a melee hit that takes the item away (opcode 112).
    local function chargeIn(sprite,rows)
        local resref=held(sprite)
        if not resref then return nil end
        for _,row in ipairs(rows) do
            for _,w in ipairs(row.spell and type(row.spell.weapons)=='table' and row.spell.weapons or {}) do
                if w.touch and w.item==resref then
                    local c={}
                    for k,v in pairs(w) do c[k]=v end
                    c.spell=row.resref
                    return c
                end
            end
        end
        local record=reader.get('ITM',resref)
        local ability=record and type(record.abilities)=='table' and record.abilities[1]
        if type(ability)~='table' or ability.attackType~=1 then return nil end
        for _,e in ipairs(type(ability.effects)=='table' and ability.effects or {}) do
            if type(e)=='table' and e.opcode==112 then
                local strike=item(resref)[1]
                if strike then
                    return {item=resref,touch=true,uses=1,attack='melee',toHit=ability.thac0,strike=strike,
                        flags=record.flags,enchantment=record.enchantment}
                end
            end
        end
    end
    -- The weapon in the creature's hand as an attack (combat-intent/weapons.lua's arms), or nil:
    -- what sense.attack reads, and what a hit casts or applies (the weapon's ability, or the
    -- ammunition a launcher shoots, classified). A launcher without ammunition is none.
    local function arms(a)
        if type(a)~='table' or type(a.item)~='string' or type(a.damage)~='number' or (a.launcher and not a.ammo) then return nil end
        local strike
        if a.ammo then strike=item(a.ammo)[1] else strike=item(a.item)[a.ability] end
        return {item=a.item,damage=a.damage,damageType=a.damageType,apr=a.apr or weapons.baseApr,thac0=a.thac0,
            ranged=a.ranged==true,range=a.range,flags=a.flags,enchantment=a.enchantment,strike=strike}
    end
    -- A summoned creature as a fighter (combat-intent/summons.lua), read once: its CRE file, the
    -- weapon in its first weapon slot and, for a launcher, the ammunition in its first filled
    -- quiver slot. nil when it cannot be read.
    local function profile(resref)
        local known=profiles[resref]
        if known==nil then
            local ok,value=pcall(function()
                local cre=reader.get('CRE',resref)
                if not cre then return nil end
                local function at(slot)
                    local index=type(cre.slots)=='table' and cre.slots[slot+1]
                    local name=type(index)=='number' and index~=65535 and type(cre.items)=='table' and cre.items[index+1]
                    return type(name)=='string' and name~='' and reader.get('ITM',name) or nil
                end
                local ammo
                for _,slot in ipairs(M.creQuiver) do
                    ammo=at(slot)
                    if ammo then break end
                end
                return summons.profile(cre,at(M.creWeapon),ammo)
            end)
            known=ok and value or false
            if profileCount<M.cacheLimit then profiles[resref]=known;profileCount=profileCount+1 end
        end
        return known or nil
    end
    -- The creatures the caster's ready summoning spells name, by resref.
    local function summoned(rows)
        local out={}
        for _,row in ipairs(rows) do
            local role=type(row.spell)=='table' and type(row.spell.roles)=='table' and row.spell.roles.summon
            if type(role)=='table' and type(role.creatures)=='table' and type(row.ready)=='number' and row.ready>0 then
                for resref in pairs(role.creatures) do
                    if valid(resref) and out[resref]==nil then out[resref]=profile(resref) or false end
                end
            end
        end
        for resref,c in pairs(out) do if c==false then out[resref]=nil end end
        return out
    end
    -- The allies a creature sees now, by id, with the creature file and gender of each.
    local function alliesInView(sprite,tick)
        local out={}
        local frame=sense.frame(g,sprite,tick,false)
        for _,a in ipairs(frame and frame.allies or {}) do
            local object=get(a.id)
            if object then out[a.id]={resref=text(object.m_resref:get()),gender=object.m_typeAI.m_Gender} end
        end
        return out
    end
    -- What the creature has ready: its spells with their classification, and the items it can
    -- drink or use from its quick slots and backpack.
    local function book(sprite)
        local snapshot,err=creature.read(g,sprite,reader)
        if not snapshot then return nil,err end
        local rows={}
        for _,s in ipairs(snapshot.spells) do
            local level=s.casterLevel or snapshot.level or 1
            if level<1 then level=1 end
            rows[#rows+1]={resref=s.resref,list=s.list,level=s.level,ready=s.ready,memorized=s.memorized,
                usable=s.usable,spell=classify(s.resref,level)}
        end
        local carried={}
        for _,it in ipairs(snapshot.items) do
            if it.slot>=M.itemFirst and it.slot<=M.itemLast then
                local abilities={}
                for i,effect in ipairs(item(it.resref)) do
                    abilities[i]={effect=effect,uses=type(it.uses)=='table' and it.uses[i] or nil}
                end
                carried[#carried+1]={resref=it.resref,abilities=abilities}
            end
        end
        return rows,carried
    end

    -- The engine's answers to the SPLPROT checks of the spells the creature has ready, for each
    -- enemy it sees. A check the engine does not answer stays unknown; the first such failure is
    -- recorded, the rest counted.
    local function mark(sprite,frame,rows)
        local wanted={}
        for _,row in ipairs(rows) do
            if row.spell and type(row.ready)=='number' and row.ready>0 and row.usable then spells.rows(row.spell,wanted) end
        end
        local read,bad,last=sense.splprot(g,sprite,frame,wanted)
        counts.marks=counts.marks+read
        if bad>0 then
            counts.markFailures=counts.markFailures+bad
            if not markError then
                markError=tostring(last):sub(1,200)
                record({kind='error',where='splprot',error=markError})
            end
        end
    end

    -- Time Stop: while one runs, every creature but its caster is frozen, and what reaches a
    -- frozen creature takes effect only when time resumes (lab, CHOICE-01). stop is the running
    -- one's caster (true if unknown); resumed the tick time was last seen running again or
    -- changing hands. Every judgement and every start of a casting member looks.
    local stop,resumed
    -- The running Time Stop's caster (true if unknown) and its seconds left, or nil.
    local function timeStop()
        local ok,n,c=pcall(function()
            local chitin=rawget(g,'EEex_EngineGlobal_CBaldurChitin')
            local engine=rawget(g,'EngineGlobals')
            if not chitin and engine then chitin=engine.g_pBaldurChitin end
            local game=chitin.m_pObjectGame
            return game.m_nTimeStop,game.m_nTimeStopCaster
        end)
        if ok and type(n)=='number' and n>0 then return type(c)=='number' and c or true,n/M.stopCount end
    end
    local function watch(tick)
        local caster=timeStop()
        if stop~=nil and caster~=stop then resumed=tick end
        if caster~=stop then stopCasts={} end
        stop=caster
    end
    local function frozen(id)
        if stop==nil or id==stop then return false end
        local target=get(id)
        if not target then return false end
        local ok,immune=pcall(function() return target.m_derivedStats.m_bImmuneToTimeStop end)
        return not (ok and type(immune)=='number' and immune~=0)
    end
    -- A finished cast whose target is frozen now waits for time to resume.
    local function wait(a,tick)
        if a.target and frozen(a.target) then
            if not a.frozen then counts.frozen=counts.frozen+1 end
            a.frozen=tick
        end
    end

    -- Whether a creature carries an effect of cast a's spell. An effect a spell lands through a
    -- sub-spell or an EFF file names that as its source (the classifier's sources).
    local function carries(target,a)
        local names=type(a.sources)=='table' and a.sources or {[a.resref]=true}
        local hit=false
        for _,list in ipairs({target.m_timedEffectList,target.m_equipedEffectList}) do
            local n=0
            g.EEex_Utility_IterateCPtrList(list,function(effect)
                n=n+1
                if n>sense.maxEffects then return true end
                if names[text(effect.m_sourceRes:get())] then hit=true;return true end
            end)
            if hit then break end
        end
        return hit
    end
    -- The effect of finished casts on their targets: a target that lost hit points, became
    -- disabled by a disable, or carries an effect of the spell was hit. A defence took when a
    -- friend it was for carries its effects.
    local function outcome(a)
        local defending=a.kind=='defence'
        if a.castTicks and a.ended-a.started<a.castTicks-M.interruptSlack then
            counts.interrupted=counts.interrupted+1;return
        end
        if a.kind=='removal' then
            -- An enemy it was for that lost effects, skins, images or its invisibility, or is gone.
            local took=0
            local enemies=type(a.hits)=='table' and a.hits or {}
            for _,id in ipairs(enemies) do
                local before=type(a.before)=='table' and a.before[id]
                if before then
                    local object=get(id)
                    if not object then took=took+1
                    else
                        local now=shown(object,a.ended)
                        if (now.effects and before.effects and now.effects<before.effects) or (now.skins or 0)<(before.skins or 0)
                            or (now.mirror or 0)<(before.mirror or 0) or (targeting.has(before.state,UNSEEN) and
                            not targeting.has(now.state,UNSEEN)) then took=took+1 end
                    end
                end
            end
            if took>0 then counts.stripped=counts.stripped+1 else counts.unstripped=counts.unstripped+1 end
            record({kind='strip',tick=a.ended,member=a.caster,spell=a.resref,mode=a.mode,enemies=#enemies,took=took})
            return
        end
        if M.CARE[a.kind] then
            local helped=0
            local friends=type(a.hits)=='table' and a.hits or {}
            for _,id in ipairs(friends) do
                local friend=get(id)
                local before=type(a.before)=='table' and a.before[id]
                if friend and before then
                    local now=sense.actor(g,friend)
                    local better=type(now.hp)=='number' and type(before.hp)=='number' and now.hp>before.hp
                    if (before.held or 0)>0 and (now.held or 0)==0 then better=true end
                    for _,bit in ipairs(M.CONDITION_BITS) do
                        if targeting.has(before.state,bit) and not targeting.has(now.state,bit) then better=true end
                    end
                    if better then helped=helped+1 end
                end
            end
            if helped>0 then counts.cared=counts.cared+1 else counts.uncared=counts.uncared+1 end
            record({kind='care',tick=a.ended,member=a.caster,spell=a.resref,castKind=a.kind,mode=a.mode,
                friends=#friends,helped=helped})
            return
        end
        if a.kind=='summon' then
            -- A caster that fell since sees nothing to judge by. An ally it did not see before
            -- came from the summons when its creature file is one the spell names, or when the
            -- spell brings creatures from monster tables and it is a summoned creature. The gender
            -- alone does not tell: lab batch H's Dark Planetar is female and Animate Dead's
            -- skeletons are neither, though both came.
            local caster=get(a.caster)
            if not caster then return end
            local joined=0
            local named=idSet(a.creatures)
            local ok,now=pcall(alliesInView,caster,a.ended)
            for id,c in pairs(ok and now or {}) do
                if not (type(a.before)=='table' and a.before[id]) and
                    (named[c.resref] or (a.monsters and choice.SUMMONED[c.gender])) then joined=joined+1 end
            end
            if joined>0 then counts.conjured=counts.conjured+1 else counts.unconjured=counts.unconjured+1 end
            record({kind='conjure',tick=a.ended,member=a.caster,spell=a.resref,mode=a.mode,expected=a.count,
                joined=joined,read=ok or nil})
            return
        end
        if not defending and (not a.target or a.mode~='creature') then return end
        if defending then
            local landed=0
            local friends=type(a.hits)=='table' and a.hits or {}
            for _,id in ipairs(friends) do
                local friend=get(id)
                if friend and carries(friend,a) then landed=landed+1 end
            end
            if landed>0 then counts.guarded=counts.guarded+1 else counts.unguarded=counts.unguarded+1 end
            record({kind='guard',tick=a.ended,member=a.caster,spell=a.resref,mode=a.mode,friends=#friends,landed=landed})
            return
        end
        local target=get(a.target)
        if not target then return end
        local hit=a.hp~=nil and target.m_baseStats.m_hitPoints<a.hp
        if not hit and a.kind=='disable' then hit=targeting.disabled(sense.actor(g,target)) end
        if not hit then hit=carries(target,a) end
        local key=a.resref..':'..a.target
        local mine=memory[a.caster] or {}
        memory[a.caster]=mine
        if hit then counts.hits=counts.hits+1;mine[key]=nil
        else counts.misses=counts.misses+1;mine[key]=(mine[key] or 0)+1 end
        record({kind='outcome',tick=a.ended,member=a.caster,spell=a.resref,target=a.target,hit=hit,misses=mine[key]})
    end
    -- A strike whose charge is gone: whether its target lost hit points, became disabled or
    -- carries an effect of the strike. The touch spell it came from (when known) remembers it.
    local function struck(s,tick)
        strikes[s.caster]=nil
        local target=any(s.target)
        local hit=false
        if target then
            hit=s.hp~=nil and target.m_baseStats.m_hitPoints<s.hp
            if not hit and s.disable then hit=targeting.disabled(sense.actor(g,target)) end
            if not hit then hit=carries(target,{resref=s.item,sources=s.sources}) end
        end
        if hit then counts.strikeHits=counts.strikeHits+1 else counts.strikeMisses=counts.strikeMisses+1 end
        if s.spell then
            local key=s.spell..':'..s.target
            local mine=memory[s.caster] or {}
            memory[s.caster]=mine
            if hit then mine[key]=nil else mine[key]=(mine[key] or 0)+1 end
        end
        record({kind='strike',tick=tick,member=s.caster,item=s.item,spell=s.spell,target=s.target,hit=hit,started=s.tick})
    end
    -- A weapon attack that is over: whether its target lost hit points meanwhile (from any hand).
    local function attacked(s,tick)
        strikes[s.caster]=nil
        local target=any(s.target)
        local hp=target and target.m_baseStats.m_hitPoints
        local hit=s.hp~=nil and type(hp)=='number' and hp<s.hp
        if hit then counts.attackHits=counts.attackHits+1 end
        record({kind='attack',tick=tick,member=s.caster,item=s.item,target=s.target,hit=hit,
            lost=hit and s.hp-hp or 0,started=s.tick})
    end

    -- Danger zones. Whether they can be read: EEex offers what M.zoneRequired names and no read
    -- has failed as a whole this session.
    local function zonesReady()
        if zoneBroken then return false end
        for _,name in ipairs(M.zoneRequired) do
            if type(rawget(g,name))~='function' then return false end
        end
        return type(rawget(g,'EEex_Projectile_Type'))=='table'
    end
    local function zoneFailed(where,err)
        counts.zoneFailures=counts.zoneFailures+1
        if not zoneError then
            zoneError=where..': '..tostring(err):sub(1,200)
            record({kind='error',where=where,error=zoneError})
        end
    end
    -- The zones of the creature's area at tick, read once a tick for each area (sense.zones), and
    -- the area's resref.
    local function zoneList(sprite,tick)
        if not zonesReady() then return {} end
        local area=sprite.m_pArea
        if area==nil then return {} end
        local key=text(area.m_resref:get())
        if zoneRead and zoneRead.tick==tick and zoneRead.area==key then return zoneRead.list,key end
        local ok,list,bad,last=pcall(sense.zones,g,area,tick)
        if not ok then
            zoneBroken=true;zoneFailed('zones',list)
            return {}
        end
        if bad>0 then zoneFailed('zone',last) end
        zoneRead={tick=tick,area=key,list=list}
        return list,key
    end
    -- What one explosion of a zone delivers, classified once by its object id. The first time, a
    -- 'zone' row keeps what was read of it and whether it could be classified.
    local function zoneSpell(z)
        local c=zoneSpells[z.id]
        if c==nil then
            if zoneSpellCount>=M.cacheLimit then zoneSpells,zoneSpellCount={},0 end
            local ok,value=pcall(function()
                local record={kind='SPL',resref=valid(z.resref) and z.resref or '',name=0,flags=0,spellType=1,exclusion=0,
                    school=0,secondary=0,level=1,casting={},abilities={{form=1,flags=0,location=2,target=4,targetCount=0,
                    range=0,minLevel=1,speed=0,projectile=z.projectile,effects=z.effects}}}
                return spells.classify(record,1,reader.lookup,{level=math.max(1,z.level or 1)})
            end)
            c=ok and type(value)=='table' and value or false
            if not ok then zoneFailed('zone-spell',value) end
            zoneSpells[z.id]=c;zoneSpellCount=zoneSpellCount+1
            record({kind='zone',tick=now(),id=z.id,resref=z.resref,x=z.x,y=z.y,radius=z.radius,repeats=z.repeats,
                delay=z.delay,counter=z.counter,source=z.source,projectile=z.projectile,pro=z.pro,list=z.list,level=z.level,
                effects=#z.effects,classified=c~=false,filter=c and type(c.area)=='table' and c.area.filter or nil})
        end
        return c or nil
    end
    -- Who cast a zone, from the caster's side: 'friend', 'enemy' or 'unknown'.
    local function zoneSide(z,frame)
        if z.source==frame.self.id then return 'friend' end
        for _,a in ipairs(frame.allies) do if a.id==z.source then return 'friend' end end
        for _,e in ipairs(frame.enemies) do if e.id==z.source then return 'enemy' end end
        local object=z.source and z.source>0 and g.EEex_GameObject_Get(z.source)
        if object and g.EEex_GameObject_IsSprite(object,true) then
            local own,their=sense.side(frame.self.ea),sense.side(object.m_typeAI.m_EnemyAlly)
            if own and their then return own==their and 'friend' or 'enemy' end
        end
        return 'unknown'
    end
    -- The zones as combat-intent/zones.lua weighs them: centre, radius, the seconds between
    -- explosions, to the next one and until it is gone, who cast it, whom it spares and what one
    -- explosion does. A zone explodes every delay+1 ticks, the next time in counter+1 ticks while its
    -- explosions left (repeats) count the next one, and it is gone the tick after its last (lab
    -- batch H).
    local function zonesFor(frame,raw)
        local out={}
        local tick=1/M.ticksPerSecond
        for _,z in ipairs(raw) do
            local c=z.radius>0 and z.delay>0 and zoneSpell(z)
            if c then
                local every=(z.delay+1)*tick
                local soon=z.counter>=0 and z.counter<=z.delay and (z.counter+1)*tick or nil
                out[#out+1]={id=z.id,x=z.x,y=z.y,radius=z.radius,every=every,next=soon,
                    left=(soon or every)+(z.repeats-1)*every+tick,repeats=z.repeats,
                    side=zoneSide(z,frame),filter=type(c.area)=='table' and c.area.filter or 'all',spell=c,resref=z.resref,
                    source=z.source}
            end
        end
        return out
    end
    -- Lasting areas (combat-intent/choice.lua): what the group has seen each enemy do in zones that
    -- hurt it, by object id: the explosions it stayed for and the zones it left. insideOf, by zone
    -- object id: the area it lies in and each enemy last seen inside it while it hurt the enemy and
    -- the enemy could walk, with the zone's explosions left then. Both live only in this session:
    -- object ids are the session's own, so a load forgets them (invalidate).
    local function tally(id,what,n)
        local s=stays[id]
        if not s then
            if stayCount>=M.cacheLimit then stays,stayCount={},0 end
            s={stay=0,left=0};stays[id]=s;stayCount=stayCount+1
        end
        s[what]=s[what]+n
        if what=='stay' then counts.stayed=counts.stayed+n else counts.left=counts.left+n end
    end
    -- Forgets the zones of area that are gone (not in present).
    local function forget(area,present)
        for id,v in pairs(insideOf) do
            if v.area==area and not present[id] then insideOf[id]=nil;insideCount=insideCount-1 end
        end
    end
    -- What the creature sees its enemies do in the zones of its area, at most once every lookTicks
    -- for each area: an enemy inside a zone that hurts it (zones.hit, with its marks for the zones'
    -- SPLPROT conditions, the creature as the other creature) and able to walk stayed for each
    -- explosion since it was last seen inside, and left the zone when next seen outside while the
    -- zone is still there. Fair play: only enemies the creature perceives count.
    local function look(sprite,tick,family)
        local raw,area=zoneList(sprite,tick)
        if not area or (lookedAt[area] and tick>=lookedAt[area] and tick-lookedAt[area]<M.lookTicks) then return end
        lookedAt[area]=tick
        if #raw==0 then forget(area,{});return end
        local frame=sense.frame(g,sprite,tick,true)
        if not frame or sense.side(frame.self.ea)~='evil' or #frame.enemies==0 then return end
        local list=zonesFor(frame,raw)
        local wanted={}
        for _,z in ipairs(list) do spells.rows(z.spell,wanted) end
        if next(wanted)~=nil then
            local _,bad,last=sense.splprot(g,sprite,frame,wanted)
            if bad>0 then zoneFailed('zone-splprot',last) end
        end
        local input={tick=tick,family=family,frame=frame,zones=list,mind=mindFor(sprite,family)}
        local present={}
        for _,z in ipairs(list) do
            present[z.id]=true
            local inside=insideOf[z.id]
            for _,e in ipairs(frame.enemies) do
                if type(e)=='table' and e.id~=nil and targeting.alive(e) then
                    local was=inside and inside.who[e.id]
                    if zones.rooted(e) then
                        if was then inside.who[e.id]=nil end
                    elseif zones.inside(z,e) then
                        if zones.hit(input,z,e,true)>0 then
                            if was and z.repeats<was then tally(e.id,'stay',was-z.repeats) end
                            if not inside then
                                if insideCount>=M.cacheLimit then insideOf,insideCount={},0 end
                                inside={area=area,who={}};insideOf[z.id]=inside;insideCount=insideCount+1
                            end
                            inside.who[e.id]=z.repeats
                        end
                    elseif was then
                        tally(e.id,'left',1);inside.who[e.id]=nil
                    end
                end
            end
        end
        forget(area,present)
    end
    -- For the choice record: the zones around the caster as the choice weighed them for its cast
    -- (zones.explain), nil without any.
    local function zoneView(input,d)
        local cast=(type(d.speed)=='number' and d.speed or 0)*zones.speedSeconds
        if cast<=0 or d.use or not zones.active(input) then return nil end
        local rows=zones.explain(input,cast)
        return #rows>0 and rows or nil
    end
    -- Whether a point lies in one of the zones read, or at their edge.
    local function inZone(raw,x,y)
        for _,z in ipairs(raw) do
            if targeting.distance(z,{x=x,y=y})<=z.radius+zones.margin then return true end
        end
        return false
    end
    -- What zones weigh about the caster itself: its saves, resistances, protections and IDS values
    -- (whether it is webbed or entangled comes with every frame), and its marks for the SPLPROT
    -- conditions of the zones' spells (as their receiver, with the zone's caster as the other
    -- creature).
    local function ready(sprite,frame,list)
        local self=frame.self
        local ok,err=pcall(sense.details,g,sprite,self)
        if not ok then zoneFailed('zone-self',err) end
        for _,z in ipairs(list) do
            local wanted={}
            spells.rows(z.spell,wanted)
            if next(wanted)~=nil then
                local source=z.source and get(z.source) or sprite
                local _,bad,last=sense.mark(g,self,sprite,source or sprite,wanted)
                if bad>0 then zoneFailed('zone-splprot',last) end
            end
        end
    end
    -- Where a way out ends: its point, else the next of its exits, moved to the nearest open spot
    -- of the area's search map where the creature fits (its personal space), as long as that still
    -- lies outside every zone it leaves. Without the search map the point itself is walked to.
    local function walkable(object,decision)
        local nearest=rawget(g,'EEex_Area_GetNearestOpenPosition')
        local spaceOf=rawget(g,'EEex_Sprite_GetPersonalSpace')
        local space
        if type(nearest)=='function' and type(spaceOf)=='function' then
            local ok,value=pcall(spaceOf,object)
            if ok and type(value)=='number' then space=value
            else zoneFailed('zone-space',ok and 'personal space '..tostring(value) or value) end
        end
        local points={decision.point}
        for _,p in ipairs(type(decision.exits)=='table' and decision.exits or {}) do points[#points+1]=p end
        for _,p in ipairs(points) do
            if type(p)=='table' and whole(p.x) and whole(p.y) then
                local x,y=p.x,p.y
                if space then
                    local ok,a,b=pcall(nearest,object.m_pArea,x,y,space)
                    if ok and type(a)=='number' and type(b)=='number' then x,y=math.floor(a),math.floor(b)
                    elseif not ok then zoneFailed('zone-nearest',a) end
                end
                local clear=whole(x) and whole(y)
                for _,z in ipairs(type(decision.zones)=='table' and decision.zones or {}) do
                    if targeting.distance(z,{x=x,y=y})<=z.radius then clear=false end
                end
                if clear then return {x=x,y=y} end
            end
        end
    end
    -- A way out that is over: whether the creature stands outside every zone it left.
    local function moved(m,sprite,tick)
        moves[sprite.m_id]=nil
        local at={x=sprite.m_pos.x,y=sprite.m_pos.y}
        local out=true
        for _,z in ipairs(m.zones) do if targeting.distance(z,at)<=z.radius then out=false end end
        if out then counts.escaped=counts.escaped+1 else counts.unescaped=counts.unescaped+1 end
        record({kind='escaped',tick=tick,member=sprite.m_id,to=m.point,at=at,out=out,took=tick-m.tick})
    end
    -- Wit: whether a rage runs on the creature (frame entry self: raging).
    local function rage(sprite,self)
        local state=rawget(g,'EEex_Sprite_GetSpellState')
        if type(state)~='function' then return end
        for _,n in ipairs(M.rageStates) do
            local ok,on=pcall(state,sprite,n)
            if ok and on then self.raging=true;return end
        end
    end
    -- Whether the pain drives a dull creature out of the zones (list) that hurt it where it stands
    -- (see the top): one draw each time its hit points have dropped since it was last looked at
    -- while a zone hurts it; once driven out it leaves until no zone hurts it there. A 'pain' row
    -- logs each draw.
    local function pain(sprite,frame,list,m,tick)
        if type(m)~='table' or m.wit~='dull' then return false end
        local id=sprite.m_id
        local hp=frame.self.hp
        local last=hurts[id]
        if last==nil then
            if hurtCount>=M.cacheLimit then hurts,hurtCount={},0 end
            hurtCount=hurtCount+1
        end
        hurts[id]=hp
        if not zones.harmed({tick=tick,frame=frame,zones=list,mind=m}) then pained[id]=nil;return false end
        if pained[id] then return true end
        if type(last)=='number' and type(hp)=='number' and hp<last then
            local chance=zones.painChance(frame.self,m.danger)
            local leaves=rng:nextInt(1,1000)<=math.floor(chance*1000+0.5)
            counts.pains=counts.pains+1
            record({kind='pain',tick=tick,member=id,hp=hp,lost=last-hp,chance=chance,leaves=leaves})
            if leaves then pained[id]=tick;return true end
        end
        return false
    end
    -- The decision for a way out (combat-intent/zones.lua's option).
    local function escaping(d,frame,id,tick,family,how,m)
        local response=M.response(d)
        if not response then return decline('bad-response') end
        counts.claims=counts.claims+1;counts.escapes=counts.escapes+1
        record({kind='choice',tick=tick,member=id,family=family,spell=d.resref,castKind=d.kind,mode=d.mode,point=d.point,
            score=d.score,worth=d.worth,walk=d.walk,how=how,zones=#d.zones,forced=d.forced,
            wit=type(m)=='table' and m.wit or nil})
        if director then director:release(id,tick) end
        return {own=true,response=response,spell=d.resref,kind='escape',mode=d.mode,point=d.point,exits=d.exits,
            zones=d.zones,walk=d.walk,hits={}}
    end
    -- A way out of a zone that hurts the creature where it stands (combat-intent/zones.lua's
    -- option), the frame it was found on and the creature's profile, or nil.
    local function exit(sprite,tick,family)
        local raw=zoneList(sprite,tick)
        if #raw==0 or not inZone(raw,sprite.m_pos.x,sprite.m_pos.y) then return nil end
        local frame=sense.frame(g,sprite,tick,false)
        if not frame or sense.side(frame.self.ea)~='evil' then return nil end
        local list=zonesFor(frame,raw)
        if #list==0 then return nil end
        ready(sprite,frame,list)
        rage(sprite,frame.self)
        local m=mindFor(sprite,family)
        local input={tick=tick,family=family,frame=frame,zones=list,mind=m}
        input.pained=pain(sprite,frame,list,m,tick)
        return zones.escape(input),frame,m
    end
    -- While SCS's round timer runs, or with no enemy in sight: that way out as the decision.
    local function flee(sprite,id,tick,family)
        local d,frame,m=exit(sprite,tick,family)
        if not d then return nil end
        return escaping(d,frame,id,tick,family,'flee',m)
    end
    -- For api:zones: whether the engine weighs zones for creature id now (see there).
    local function weighs(id,family)
        local sprite=get(id)
        if not sprite or sense.side(sprite.m_typeAI.m_EnemyAlly)~='evil' then return false end
        local action=sprite.m_curAction.m_actionID
        local s=strikes[id]
        local held=pending[id] or (s and M.ATTACKS[action] and s)
        local cast=running[id]
        local tick=now()
        -- A dull creature sees no zone: SCS's cloud blocks stand aside, and it stays until the pain
        -- drives it out (flee, or SCS's escape breaking its own action).
        local dull=mindFor(sprite,family).wit=='dull'
        if not held and not targeting.CASTS[action] then
            -- With no enemy in sight the engine takes the round only to lead the creature out of
            -- a zone that hurts it (its claim then does, through flee); else SCS's own escapes,
            -- runs from a marker and stand-still run (lab batches H7 and H8: SCS's run from a
            -- Cloudkill's marker left mages that saw no enemy standing in an Incendiary Cloud for
            -- 34 to 38 seconds).
            if dull then return true end
            local frame=sense.frame(g,sprite,tick,false)
            if frame and #frame.enemies>0 then return true end
            return exit(sprite,tick,family)~=nil
        end
        if dull then return not pained[id] end
        local known=(held and held.known) or (cast and targeting.CASTS[action] and cast.known) or {}
        local fresh={}
        for _,z in ipairs(zoneList(sprite,tick)) do
            if not known[z.id] and inZone({z},sprite.m_pos.x,sprite.m_pos.y) then fresh[#fresh+1]=z end
        end
        if #fresh==0 then return true end
        local frame=sense.frame(g,sprite,tick,false)
        if not frame then return false end
        local list=zonesFor(frame,fresh)
        if #list==0 then return true end
        ready(sprite,frame,list)
        return not zones.harmed({tick=tick,family=family,frame=frame,zones=list,mind=mindFor(sprite,family)})
    end

    local function judge(tick)
        watch(tick)
        for id,a in pairs(running) do
            local sprite=get(id)
            local action=sprite and sprite.m_curAction
            local ours=action and M.CASTS[action.m_actionID] and text(action.m_string1.m_pchData:get())==a.resref
            if not ours then
                a.ended=tick;running[id]=nil;wait(a,tick)
                if #judging<M.judgeLimit then judging[#judging+1]=a end
            end
        end
        local keep={}
        for _,a in ipairs(judging) do
            wait(a,tick)
            -- outcomeTicks count from the cast's end, or from when time resumed for a target a
            -- Time Stop froze.
            local from=a.ended
            if a.frozen then
                from=math.max(from,a.frozen)
                if resumed and resumed>=a.frozen then from=math.max(from,resumed) end
            end
            if tick<a.ended then
            elseif tick-from>=M.outcomeTicks then outcome(a)
            else keep[#keep+1]=a end
        end
        judging=keep
    end

    local function decide(view,family)
        if not enabled or missing then return decline(missing and 'missing' or 'off') end
        if not M.families[family] then return decline('family') end
        local tick=now()
        if type(tick)~='number' then return decline('no-clock') end
        local id=view.id
        known[id]=true
        local sprite=get(id)
        if not sprite then return decline('no-sprite') end
        judge(tick)
        local looked,lookError=pcall(look,sprite,tick,family)
        if not looked then zoneFailed('zone-look',lookError) end
        local p=pending[id]
        if p then
            -- A cast queued while the casting aura (the round of the creature's last cast) runs
            -- waits for it, as SCS's casts do.
            if g.EEex_Sprite_GetCastTimer(sprite)~=-1 then p.waiting=tick end
            if tick>=p.tick and tick-(p.waiting or p.tick)<=M.pendingTicks then
                counts.holds=counts.holds+1;return {hold=true}
            end
            pending[id]=nil;counts.lost=counts.lost+1
            record({kind='lost',tick=tick,member=id,spell=p.resref,target=p.target,queued=p.tick})
            if director then director:release(id,tick) end
        end
        -- The engine's own cast or drink is held while it is the creature's action (judge has
        -- ended it otherwise). One that became the action while the casting aura of the creature's
        -- last cast ran waits for the aura, and SCS's blocks below the hook would replace it
        -- meanwhile (lab batch H: SCS's attack block took the place of the engine's potions). It is
        -- held while the aura runs or a Time Stop freezes the creature, and for its casting time
        -- and pendingTicks from the latest of its start, the aura last seen busy and time resuming;
        -- then SCS has the round.
        local r=running[id]
        if r then
            if g.EEex_Sprite_GetCastTimer(sprite)~=-1 then r.waiting=tick end
            local from=math.max(r.started or tick,r.waiting or 0,resumed or 0)
            if frozen(id) or tick-from<=(r.castTicks or 0)+M.pendingTicks then
                counts.holds=counts.holds+1;return {hold=true}
            end
        end
        -- A strike runs while the creature swings or SCS's round timer runs (two rounds at most);
        -- once its charge is gone it is judged. A weapon attack runs while the creature attacks,
        -- or while the timer runs and its target lives (two rounds at most).
        local s=strikes[id]
        if s and s.weapon then
            local target=get(s.target)
            local alive=target~=nil and targeting.alive(sense.actor(g,target))
            if tick-s.tick<M.strikeTicks and (M.ATTACKS[sprite.m_curAction.m_actionID] or
                (alive and M.timerRunning(g,sprite,tick))) then
                counts.holds=counts.holds+1;return {hold=true}
            end
            attacked(s,tick)
        elseif s then
            if held(sprite)~=s.item then struck(s,tick)
            elseif tick-s.tick<M.strikeTicks and (M.ATTACKS[sprite.m_curAction.m_actionID] or M.timerRunning(g,sprite,tick)) then
                counts.holds=counts.holds+1;return {hold=true}
            else strikes[id]=nil end
        end
        -- A way out of a zone runs while the creature walks it; then it is judged.
        local m=moves[id]
        if m then
            if tick-m.tick<m.limit and (sprite.m_curAction.m_actionID==M.MOVE or tick-m.tick<M.moveGrace) then
                counts.holds=counts.holds+1;return {hold=true}
            end
            moved(m,sprite,tick)
        end
        -- The round is free once SCS's timer has run out, even while the casting aura of the
        -- last cast still runs: SCS's timer counts a round from the cast's queueing, the aura
        -- from its start, so the aura nearly always outlasts the timer. A queued cast waits for
        -- the aura, SCS's and the engine's alike. While the timer runs, a creature that is not
        -- casting may still walk out of a zone that hurts it.
        if M.timerRunning(g,sprite,tick) then
            if not targeting.CASTS[sprite.m_curAction.m_actionID] then
                local d=flee(sprite,id,tick,family)
                if d then return d end
            end
            return decline('timer')
        end
        if targeting.CASTS[sprite.m_curAction.m_actionID] then return decline('casting') end
        local frame=sense.frame(g,sprite,tick,true)
        if not frame then return decline('no-frame') end
        if sense.side(frame.self.ea)~='evil' then return decline('side') end
        if #frame.enemies==0 then
            local d=flee(sprite,id,tick,family)
            if d then return d end
            return decline('no-enemy')
        end
        local rows,carried=book(sprite)
        if not rows then failed('book',carried);return nil end
        mark(sprite,frame,rows)
        local bad,last=sense.defend(g,frame,tick,reader,effectsOf)
        if bad>0 then
            counts.guardFailures=counts.guardFailures+bad
            if not guardError then
                guardError=tostring(last):sub(1,200)
                record({kind='error',where='guard',error=guardError})
            end
        end
        -- What a removal could take from each enemy, read only when a ready spell removes; an enemy
        -- whose effects cannot be read keeps none (its removal is worth nothing).
        if strips(rows) then
            for _,e in ipairs(frame.enemies) do
                local object=get(e.id)
                if object then
                    local ok,value=pcall(sense.wards,g,object,tick,single)
                    if ok then e.wards=value
                    else
                        counts.wardFailures=counts.wardFailures+1
                        if not wardError then
                            wardError=tostring(value):sub(1,200)
                            record({kind='error',where='wards',error=wardError})
                        end
                    end
                end
            end
        end
        counts.decisions=counts.decisions+1
        if g.EEex_Sprite_GetStat(sprite,M.alacrityStat)>0 then frame.self.alacrity=true end
        frame.self.thac0=sense.thac0(g,sprite)
        frame.self.charge=chargeIn(sprite,rows)
        lastCharge=frame.self.charge and frame.self.charge.item or nil
        frame.self.magicItem=held(sprite)~=nil
        -- Seconds until the casting aura frees: a cast chosen now starts casting then.
        local aura=g.EEex_Sprite_GetCastTimer(sprite)
        frame.self.aura=type(aura)=='number' and aura>=0 and math.max(0,M.auraTicks-aura)/M.ticksPerSecond or 0
        -- A weapon that cannot be read leaves the caster without a weapon attack, nothing more.
        local read,err=pcall(function()
            local own=sense.attack(g,sprite,reader)
            frame.self.apr=own.apr
            frame.self.weapon=arms(own)
        end)
        if not read then
            counts.weaponFailures=counts.weaponFailures+1
            if not weaponError then
                weaponError=tostring(err):sub(1,200)
                record({kind='error',where='weapon',error=weaponError})
            end
        end
        local holder,left=timeStop()
        local input={tick=tick,family=family,frame=frame,spells=rows,items=carried,lastDefence=lastDefence[id],
            plan=director and director:plan(id,tick) or {},memory=memory[id] or {},mind=mindFor(sprite,family),rng=rng,
            creatures=summoned(rows),stays=stays}
        -- The zones in the area, with what they weigh about the caster itself.
        local raw=zoneList(sprite,tick)
        local seen={}
        for _,z in ipairs(raw) do seen[#seen+1]=z.id end
        if #raw>0 then
            input.zones=zonesFor(frame,raw)
            if #input.zones>0 then ready(sprite,frame,input.zones) end
        end
        rage(sprite,frame.self)
        input.pained=pain(sprite,frame,input.zones or {},input.mind,tick)
        if holder~=nil then
            input.timeStop={caster=holder,left=left}
            if holder==id then input.stopCasts=stopCasts[id] or {} end
        end
        -- The share of a spell slot's cost that counts now, kept for the log.
        input.slots=choice.slotShare(input)
        local d,why,options,rejected=choice.decide(input)
        lastDetail=rejected
        local top={}
        for i=1,math.min(3,#options) do
            local o=options[i]
            top[i]={spell=o.resref,kind=o.kind,target=o.target,point=o.point,score=o.score,hits=#o.hits,finish=o.finish}
        end
        if not d then
            if why~='no-option' then
                record({kind='decline',tick=tick,member=id,family=family,reason=why,top=top,charge=lastCharge,
                    rejected=lastCharge and rejected or nil,slots=input.slots})
            end
            return decline(why)
        end
        if d.kind=='escape' then return escaping(d,frame,id,tick,family,why,input.mind) end
        local response=M.response(d)
        if not response then return decline('bad-response') end
        counts.claims=counts.claims+1
        if d.kind=='defence' then counts.defences=counts.defences+1 end
        if d.kind=='opener' then counts.openers=counts.openers+1 end
        if d.kind=='touch' then counts.touches=counts.touches+1 end
        if d.kind=='arm' then counts.arms=counts.arms+1 end
        if d.kind=='heal' then counts.heals=counts.heals+1 end
        if d.kind=='cure' then counts.cures=counts.cures+1 end
        if d.use then counts.potions=counts.potions+1 end
        if d.kind=='summon' then counts.summons=counts.summons+1 end
        if d.kind=='removal' then counts.removals=counts.removals+1 end
        if d.release then counts.releases=counts.releases+1 end
        record({kind='choice',tick=tick,member=id,family=family,spell=d.resref,castKind=d.kind,mode=d.mode,
            target=d.target,point=d.point,score=d.score,worth=d.worth,hits=d.hits,how=why,top=top,
            focus=input.plan.focus,rule=d.rule,stop=input.timeStop and input.timeStop.left or nil,
            alacrity=frame.self.alacrity or nil,release=d.release,use=d.use,creatures=d.creatures,count=d.count,
            rest=d.rest,slots=input.slots,finish=d.finish,aura=frame.self.aura~=0 and frame.self.aura or nil,
            inZones=zoneView(input,d),lasting=d.lasting,wit=input.mind.wit})
        -- A disable claims its targets in the group at once, so that another member deciding
        -- before this cast starts leaves them alone; any other decision gives earlier claims back.
        if director then
            if d.kind=='disable' or M.CARE[d.kind] then director:reserve(id,d.hits,tick) else director:release(id,tick) end
        end
        local spell
        for _,row in ipairs(rows) do if row.resref==d.resref then spell=row.spell end end
        local sources=spell and spell.sources or nil
        local before
        -- A summons is judged by the allies the caster sees after it and not before.
        if d.kind=='summon' then
            before={}
            for _,a in ipairs(frame.allies) do before[a.id]=true end
        end
        -- A removal is judged by what shows of its enemies' protections after it and before.
        if d.kind=='removal' then
            before={}
            for _,h in ipairs(d.hits or {}) do
                local object=get(h)
                if object then before[h]=shown(object,tick) end
            end
        end
        if M.CARE[d.kind] then
            before={}
            local friends={[frame.self.id]=frame.self}
            for _,a in ipairs(frame.allies) do friends[a.id]=a end
            for _,h in ipairs(d.hits or {}) do
                local f=friends[h]
                if f then before[h]={hp=f.hp,state=f.state,held=f.held} end
            end
        end
        local disable
        if d.kind=='strike' then
            local strike=frame.self.charge.strike
            sources=strike.sources
            disable=type(strike.roles)=='table' and type(strike.roles.disable)=='table' or nil
        end
        return {own=true,response=response,spell=d.resref,kind=d.kind,mode=d.mode,target=d.target,point=d.point,
            self=d.self,hits=d.hits,castTicks=spell and type(spell.speed)=='number' and spell.speed*9 or nil,
            sources=sources,expected=d.expected,disable=disable,charge=d.kind=='strike' and d.spell or nil,
            use=d.use,before=before,count=d.count,creatures=d.creatures,monsters=d.monsters,known=seen}
    end
    -- From the gate, each time a hooked script asks: nil (SCS's round), {hold=true} while the
    -- engine's queued cast has not started or its own cast or drink is the creature's action, or
    -- the decision.
    function api:decide(view,family)
        lastReason,lastDetail,lastCharge=nil,nil,nil
        local ok,result=pcall(decide,view,family)
        if trace and sink and lastReason then
            pcall(sink,{kind='declined',tick=now(),member=type(view)=='table' and view.id or nil,family=family,
                reason=lastReason,rejected=(lastReason=='no-option' or lastCharge) and lastDetail or nil,charge=lastCharge})
        end
        if ok then return result end
        failed('decide',result)
    end

    -- Right before the gate queues the response: the caster can still cast and the target is
    -- still a living, visible creature without sanctuary; then the caster's EEex_Target table
    -- names it. Decisions of other deciders (lab experiments) pass unchanged.
    local function prepare(object,decision)
        if not decision.own then return true end
        if not enabled or missing then return 'skipped' end
        local tick=now()
        if type(tick)~='number' then return 'skipped' end
        if decision.kind~='escape' and M.timerRunning(g,object,tick) then return 'skipped' end
        local hp
        if decision.target and not decision.point and not decision.self then
            local target=get(decision.target)
            if not target then return 'skipped' end
            local seen=sense.actor(g,target)
            -- Sanctuary keeps out enemies' casts, not an ally's protection, heal or cure.
            if not targeting.alive(seen) or ((seen.sanctuary or 0)>0 and not M.FRIENDLY[decision.kind]) then return 'skipped' end
            if targeting.has(seen.state,UNSEEN) and not (g.EEex_Sprite_GetStat(object,sense.stats.seeInvisible)>0 or
                g.EEex_Sprite_GetStat(object,sense.stats.trueSight)>0) then return 'skipped' end
            local aux=g.EEex_GetUDAux(object)
            local make=rawget(g,'EEex_Utility_GetOrCreateTable')
            local names
            if type(make)=='function' then names=make(aux,'EEex_Target')
            else
                names=aux.EEex_Target
                if type(names)~='table' then names={};aux.EEex_Target=names end
            end
            names[M.targetName]=decision.target
            hp=seen.hp
        end
        local known=idSet(decision.known)
        if decision.kind=='strike' then
            strikes[object.m_id]={caster=object.m_id,item=decision.spell,spell=decision.charge,target=decision.target,
                hp=hp,tick=tick,sources=decision.sources,disable=decision.disable,known=known}
            counts.performed=counts.performed+1;counts.strikes=counts.strikes+1
            record({kind='swing',tick=tick,member=object.m_id,item=decision.spell,target=decision.target})
            return true
        end
        if decision.kind=='weapon' then
            strikes[object.m_id]={caster=object.m_id,item=decision.spell,weapon=true,target=decision.target,hp=hp,tick=tick,
                known=known}
            counts.performed=counts.performed+1;counts.attacks=counts.attacks+1
            record({kind='swing',tick=tick,member=object.m_id,item=decision.spell,target=decision.target,weapon=true})
            return true
        end
        -- A way out: to the nearest open spot that still lies outside the zones it leaves.
        if decision.kind=='escape' then
            local point=walkable(object,decision)
            if not point then return 'skipped' end
            decision.response='MoveToPoint(['..point.x..'.'..point.y..'])'
            local walk=type(decision.walk)=='number' and decision.walk or 0
            moves[object.m_id]={tick=tick,point=point,zones=type(decision.zones)=='table' and decision.zones or {},
                limit=math.ceil(walk*M.ticksPerSecond*2)+M.moveMargin}
            counts.performed=counts.performed+1
            record({kind='move',tick=tick,member=object.m_id,from={x=object.m_pos.x,y=object.m_pos.y},to=point})
            return true
        end
        pending[object.m_id]={caster=object.m_id,resref=decision.spell,kind=decision.kind,mode=decision.mode,
            target=decision.target,point=decision.point,hits=decision.hits,tick=tick,hp=hp,
            castTicks=decision.castTicks,sources=decision.sources,expected=decision.expected,before=decision.before,
            count=decision.count,creatures=decision.creatures,monsters=decision.monsters,known=known}
        counts.performed=counts.performed+1
        return true
    end
    -- A decision that is not queued gives its claims in the group back.
    function api:prepare(object,decision)
        local ok,result=pcall(prepare,object,decision)
        if ok and result~='skipped' then return result end
        if ok then counts.skipped=counts.skipped+1 else failed('prepare',result) end
        if director and type(decision)=='table' and decision.own then
            pcall(function() director:release(object.m_id,now()) end)
        end
        return ok and result or false
    end

    -- A defence a creature that asks the engine starts, the engine's or its script's, starts
    -- its pause before the next one (mind.redefend), as SCS's redefend timer does: a cast, or a
    -- drink of an item one of whose abilities defends.
    local function defended(sprite,action,tick)
        local id=sprite.m_id
        if not known[id] then return end
        if action.m_actionID==M.USE then
            local resref=text(action.m_string1.m_pchData:get())
            if not valid(resref) then return end
            for _,effect in ipairs(item(resref)) do
                if defence.defence(effect) then lastDefence[id]=tick;return end
            end
            return
        end
        if not targeting.CASTS[action.m_actionID] then return end
        local resref=directors.resref(action)
        if not resref then return end
        local ok,level=pcall(g.EEex_Sprite_GetCasterLevelForSpell,sprite,resref,false)
        if not ok or type(level)~='number' or level<1 then level=1 end
        local spell=classify(resref,level)
        if spell and defence.defence(spell) then lastDefence[id]=tick end
    end
    -- From the director's started-action listener, for every sprite's every action: the
    -- engine's queued cast starting (returned for the director's picture), or another action
    -- ending a running one.
    local function started(sprite,action,tick)
        local id=sprite.m_id
        defended(sprite,action,tick)
        local p,r=pending[id],running[id]
        if not p and not r then return nil end
        if r then
            r.ended=tick;running[id]=nil
            watch(tick);wait(r,tick)
            if #judging<M.judgeLimit then judging[#judging+1]=r end
        end
        if p and M.CASTS[action.m_actionID] and text(action.m_string1.m_pchData:get())==p.resref then
            pending[id]=nil;p.started=tick;running[id]=p
            counts.started=counts.started+1
            -- A cast started in the caster's own Time Stop lands when time resumes.
            watch(tick)
            if stop==id and (p.kind=='damage' or p.kind=='disable') then
                local mine=stopCasts[id] or {}
                stopCasts[id]=mine
                if #mine<M.stopCastLimit then mine[#mine+1]={kind=p.kind,hits=p.hits,expected=p.expected} end
            end
            record({kind='start',tick=tick,member=id,spell=p.resref,target=p.target,point=p.point,
                waited=tick-p.tick})
            return {spell=p.resref,role=p.kind,target=p.target,hits=p.hits}
        end
    end
    function api:started(sprite,action,tick)
        local ok,result=pcall(started,sprite,action,tick)
        if ok then return result end
        failed('started',result)
    end

    function api:setEnabled(value)
        assert(type(value)=='boolean');enabled=value
        if not value then pending,moves={},{} end
    end
    -- Whether the engine weighs danger zones for creature id of family now (BGSE_Zones: SCS's own
    -- cloud blocks stand aside meanwhile): not for a creature off the engine's
    -- side, and with no enemy in sight only when the engine has a way out of a zone that hurts it.
    -- While it casts, or swings in a strike or weapon round of the engine's, the hook cannot break
    -- that action (its own block runs it), so a zone that hurts the creature where it stands and
    -- that the engine did not know when it chose the action lets SCS's escape break it off, as
    -- SCS's creatures always do.
    function api:zones(family,id)
        if not (enabled and not missing and M.families[family]==true and zonesReady()) then return false end
        local ok,result=pcall(weighs,id,family)
        if ok then return result==true end
        zoneFailed('zone-guard',result)
        return false
    end
    function api:attach(r) root=r end
    function api:setSink(fn) assert(fn==nil or type(fn)=='function');sink=fn end
    function api:setTrace(value) assert(type(value)=='boolean');trace=value end
    -- Labs: the default profile with these changes (combat-intent/mind.lua), e.g. {caution=0}
    -- to weigh no defences; nil restores the default. Returns false and the bad field.
    function api:setMind(changes)
        local m,bad=mind.new(changes)
        if not m then return false,bad end
        defaultMind=m;mindVersion=mindVersion+1
        return true
    end
    -- Labs: wit on or off (off: every creature thinks with the default profile, clever), and wit
    -- overrides by creature file (combat-intent/mind.lua, M.wit). Returns false and why for a bad
    -- table.
    function api:setWit(value)
        assert(type(value)=='boolean');witOn=value;minds,mindCount={},0
    end
    function api:setWitOverrides(t)
        if t~=nil and type(t)~='table' then return false,'overrides' end
        witOverrides=t;minds,mindCount={},0
        return true
    end
    function api:invalidate()
        pending,running,judging,memory,stop,resumed={},{},{},{},nil,nil
        lastDefence,known,stopCasts,strikes={},{},{},{}
        moves,zoneRead,zoneSpells,zoneSpellCount,zoneBroken={},nil,{},0,false
        stays,stayCount,insideOf,insideCount,lookedAt={},0,{},0,{}
        minds,mindCount,hurts,hurtCount,pained={},0,{},0,{}
    end
    function api:inspect()
        local copy=function(t) local c={};for k,v in pairs(t) do c[k]=v end;return c end
        local rows,first={},(nextRow-size-1)%M.logCapacity+1
        for i=0,size-1 do rows[#rows+1]=log[(first+i-1)%M.logCapacity+1] end
        local open,busy,remembered=0,0,0
        for _ in pairs(pending) do open=open+1 end
        for _ in pairs(running) do busy=busy+1 end
        for _,mine in pairs(memory) do for _ in pairs(mine) do remembered=remembered+1 end end
        return {enabled=enabled,missing=missing or false,trace=trace,counts=copy(counts),reasons=copy(reasons),
            pending=open,running=busy,judging=#judging,remembered=remembered,log=rows,lastError=lastError or false,
            markError=markError or false,guardError=guardError or false,weaponError=weaponError or false,
            wardError=wardError or false,zoneError=zoneError or false,witError=witError or false,wit=witOn,moving=(function()
                local n=0;for _ in pairs(moves) do n=n+1 end;return n end)(),stays=(function()
                local c={};for id,s in pairs(stays) do c[id]={stay=s.stay,left=s.left} end;return c end)()}
    end
    return api
end
return M
