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
local sense=require('adapters.eeex.sense')
local creature=require('adapters.eeex.creature')
local resources=require('adapters.eeex.resources')
local directors=require('adapters.eeex.director')
local spells=require('combat-intent.spells')
local targeting=require('combat-intent.targeting')
local defence=require('combat-intent.defence')
local weapons=require('combat-intent.weapons')
local choice=require('combat-intent.choice')
local mind=require('combat-intent.mind')
local rngs=require('kernel.rng')
local M={}
M.families={mage=true,priest=true}
-- Game ticks (15 a second). A queued cast that has not started pendingTicks after it was
-- queued, or after the creature's casting aura was last seen busy, is given up; outcomeTicks
-- after a cast ends, or after time resumes if a Time Stop froze the target, its effect on the
-- target is judged.
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
M.required={'EEex_GameObject_Get','EEex_GameObject_IsSprite','EEex_Sprite_GetCastTimer',
    'EEex_Sprite_GetLocalInt','EEex_GetUDAux','EEex_Sprite_GetState','EEex_Sprite_GetStat'}
-- STATS.IDS: WIZARD_IMPROVED_ALACRITY, what SCS tests. Improved Alacrity (SPWI921, with and
-- without Spell Revisions, and SCS's DW#QALAC) sets it with opcode 282 p2=9. AURACLEANSING is
-- not used: an item could hold it for good.
M.alacrityStat=165
-- The game's Time Stop count falls by two a tick (learned.md, section 1): seconds = count/30.
M.stopCount=30
-- Casts remembered per caster in its own Time Stop.
M.stopCastLimit=32
local UNSEEN=targeting.STATE.invisible+targeting.STATE.improvedInvisible

local function text(value) return (value:match('^[^%z]*'):upper()) end
local function valid(resref) return type(resref)=='string' and #resref>0 and #resref<=8 and not resref:find('[^A-Z0-9_#%-]') end
local function whole(v) return type(v)=='number' and v>=0 and v<65536 and v%1==0 end

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
    local mindFor=options.mindFor or function() return defaultMind end
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
    local pending,running,judging,memory={},{},{},{}
    -- lastDefence: the tick each creature last started a defence; known: the creatures that
    -- asked the engine (hooked mages and priests); stopCasts: what the holder of the running
    -- Time Stop started in it.
    -- strikes: each creature's strike with a touch charge, until the charge is gone, or its
    -- weapon attack (weapon=true), until it is over.
    local lastDefence,known,stopCasts,strikes={},{},{},{}
    local counts={decisions=0,claims=0,declines=0,performed=0,skipped=0,started=0,lost=0,interrupted=0,
        hits=0,misses=0,errors=0,holds=0,frozen=0,marks=0,markFailures=0,defences=0,guarded=0,unguarded=0,
        guardFailures=0,openers=0,touches=0,strikes=0,strikeHits=0,strikeMisses=0,arms=0,attacks=0,attackHits=0,
        weaponFailures=0,releases=0,heals=0,cures=0,potions=0,cared=0,uncared=0}
    local reasons={}
    local log,nextRow,size={},1,0
    local root,sink,lastError,markError,guardError,weaponError
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
        -- The round is free once SCS's timer has run out, even while the casting aura of the
        -- last cast still runs: SCS's timer counts a round from the cast's queueing, the aura
        -- from its start, so the aura nearly always outlasts the timer. A queued cast waits for
        -- the aura, SCS's and the engine's alike.
        if M.timerRunning(g,sprite,tick) then return decline('timer') end
        if targeting.CASTS[sprite.m_curAction.m_actionID] then return decline('casting') end
        local frame=sense.frame(g,sprite,tick,true)
        if not frame then return decline('no-frame') end
        if sense.side(frame.self.ea)~='evil' then return decline('side') end
        if #frame.enemies==0 then return decline('no-enemy') end
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
        counts.decisions=counts.decisions+1
        if g.EEex_Sprite_GetStat(sprite,M.alacrityStat)>0 then frame.self.alacrity=true end
        frame.self.thac0=sense.thac0(g,sprite)
        frame.self.charge=chargeIn(sprite,rows)
        lastCharge=frame.self.charge and frame.self.charge.item or nil
        frame.self.magicItem=held(sprite)~=nil
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
            plan=director and director:plan(id,tick) or {},memory=memory[id] or {},mind=mindFor(sprite,family),rng=rng}
        if holder~=nil then
            input.timeStop={caster=holder,left=left}
            if holder==id then input.stopCasts=stopCasts[id] or {} end
        end
        local d,why,options,rejected,kept=choice.decide(input)
        lastDetail=rejected
        local top={}
        for i=1,math.min(3,#options) do
            local o=options[i]
            top[i]={spell=o.resref,kind=o.kind,target=o.target,point=o.point,score=o.score,hits=#o.hits}
        end
        if not d then
            if why~='no-option' then
                record({kind='decline',tick=tick,member=id,family=family,reason=why,top=top,charge=lastCharge,
                    rejected=lastCharge and rejected or nil,kept=kept})
            end
            return decline(why)
        end
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
        if d.release then counts.releases=counts.releases+1 end
        record({kind='choice',tick=tick,member=id,family=family,spell=d.resref,castKind=d.kind,mode=d.mode,
            target=d.target,point=d.point,score=d.score,worth=d.worth,hits=d.hits,how=why,top=top,
            focus=input.plan.focus,rule=d.rule,stop=input.timeStop and input.timeStop.left or nil,
            alacrity=frame.self.alacrity or nil,release=d.release,use=d.use})
        -- A disable claims its targets in the group at once, so that another member deciding
        -- before this cast starts leaves them alone; any other decision gives earlier claims back.
        if director then
            if d.kind=='disable' or M.CARE[d.kind] then director:reserve(id,d.hits,tick) else director:release(id,tick) end
        end
        local spell
        for _,row in ipairs(rows) do if row.resref==d.resref then spell=row.spell end end
        local sources=spell and spell.sources or nil
        local before
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
            use=d.use,before=before}
    end
    -- From the gate, each time a hooked script asks: nil (SCS's round), {hold=true} while the
    -- engine's queued cast has not started, or the decision.
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
        if M.timerRunning(g,object,tick) then return 'skipped' end
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
        if decision.kind=='strike' then
            strikes[object.m_id]={caster=object.m_id,item=decision.spell,spell=decision.charge,target=decision.target,
                hp=hp,tick=tick,sources=decision.sources,disable=decision.disable}
            counts.performed=counts.performed+1;counts.strikes=counts.strikes+1
            record({kind='swing',tick=tick,member=object.m_id,item=decision.spell,target=decision.target})
            return true
        end
        if decision.kind=='weapon' then
            strikes[object.m_id]={caster=object.m_id,item=decision.spell,weapon=true,target=decision.target,hp=hp,tick=tick}
            counts.performed=counts.performed+1;counts.attacks=counts.attacks+1
            record({kind='swing',tick=tick,member=object.m_id,item=decision.spell,target=decision.target,weapon=true})
            return true
        end
        pending[object.m_id]={caster=object.m_id,resref=decision.spell,kind=decision.kind,mode=decision.mode,
            target=decision.target,point=decision.point,hits=decision.hits,tick=tick,hp=hp,
            castTicks=decision.castTicks,sources=decision.sources,expected=decision.expected,before=decision.before}
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
    -- its pause before the next one (mind.redefend), as SCS's redefend timer does.
    local function defended(sprite,action,tick)
        local id=sprite.m_id
        if not known[id] or not targeting.CASTS[action.m_actionID] then return end
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
        if not value then pending={} end
    end
    function api:attach(r) root=r end
    function api:setSink(fn) assert(fn==nil or type(fn)=='function');sink=fn end
    function api:setTrace(value) assert(type(value)=='boolean');trace=value end
    -- Labs: the default profile with these changes (combat-intent/mind.lua), e.g. {caution=0}
    -- to weigh no defences; nil restores the default. Returns false and the bad field.
    function api:setMind(changes)
        local m,bad=mind.new(changes)
        if not m then return false,bad end
        defaultMind=m
        return true
    end
    function api:invalidate()
        pending,running,judging,memory,stop,resumed={},{},{},{},nil,nil
        lastDefence,known,stopCasts,strikes={},{},{},{}
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
            markError=markError or false,guardError=guardError or false,weaponError=weaponError or false}
    end
    return api
end
return M
