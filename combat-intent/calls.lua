-- Creature-specific Call-for-Help & Flair Shout rules (Christopher, 2026-11-12).
-- Replaces area-wide telepathy on open maps with local earshot radii, creature-type profiles
-- ('silent', 'pack', 'warband', 'map'), difficulty-scaled hop caps (0 hops up to Core, 1 hop on
-- Hard/Insane for warbands, never whole-map chain pulls), and rate-limited overhead flair shouts.
-- Pure Lua; no EEex or global state here.
local targeting=require('combat-intent.targeting')
local M={}

M.TICKS_PER_SECOND=15

M.CONFIG={
    alertSeconds=60,
    relayRadiusFactor=0.85,
    minGlobalShoutGapSeconds=8,
    profiles={
        silent={
            radiusByDifficulty={0,0,0,0,0},
            maxHopsByDifficulty={0,0,0,0,0},
            sameRaceOnly=false,
            shouts=false,
            cooldownSeconds=0,
            replyMinAlerted=99,
        },
        pack={
            radiusByDifficulty={550,600,650,700,750},
            maxHopsByDifficulty={0,0,0,0,0},
            sameRaceOnly=true,
            shouts=true,
            cooldownSeconds=60,
            replyMinAlerted=99,
        },
        warband={
            radiusByDifficulty={600,650,700,800,850},
            maxHopsByDifficulty={0,0,0,1,1},
            sameRaceOnly=false,
            shouts=true,
            cooldownSeconds=45,
            replyMinAlerted=3,
        },
        map={
            radiusByDifficulty={99999,99999,99999,99999,99999},
            maxHopsByDifficulty={0,0,0,0,0},
            sameRaceOnly=false,
            shouts=true,
            cooldownSeconds=45,
            replyMinAlerted=3,
        },
    },
}

-- Explicit RACE.IDS overrides checked before GENERAL.IDS (so intelligent undead like LICH and
-- VAMPIRE stay 'warband' while mindless undead stay 'silent', and pack beasts stay 'pack').
M.RACE_PROFILE={
    -- Intelligent undead
    LICH='warband',DEMILICH='warband',VAMPIRE='warband',VAMPYRE='warband',
    -- Pack beasts
    WOLF='pack',DOG='pack',WORG='pack',
    -- Mindless undead, constructs, oozes, insects, arachnids & solitary/non-calling monsters
    SKELETON='silent',ZOMBIE='silent',GHOUL='silent',SHADOW='silent',WRAITH='silent',
    SPECTRE='silent',MUMMY='silent',GOLEM='silent',STATUE='silent',SLIME='silent',
    ANKHEG='silent',SPIDER='silent',BEETLE='silent',CARRIONCRAWLER='silent',
    BASILISK='silent',BEAR='silent',WYVERN='silent',MIMIC='silent',SHRIEKER='silent',
    OTYUGH='silent',MYCONID='silent',SHAMBLING_MOUND='silent',CAT='silent',
    UMBER_HULK='silent',ETTERCAP='silent',DRAGON='silent',
    -- Intelligent warband & humanoid races
    HUMAN='warband',ELF='warband',HALF_ELF='warband',DWARF='warband',HALFLING='warband',
    GNOME='warband',HALFORC='warband',TIEFLING='warband',AASIMAR='warband',
    DUERGAR='warband',SVIRFNEBLIN='warband',GITHYANKI='warband',
    HOBGOBLIN='warband',GNOLL='warband',KOBOLD='warband',XVART='warband',
    GIBBERLING='warband',ORC='warband',OGRE='warband',HALF_OGRE='warband',
    OGRILLON='warband',GOBLIN='warband',BUGBEAR='warband',TASLOI='warband',
    LIZARDMAN='warband',SAHUAGIN='warband',['KUO-TOA']='warband',YUANTI='warband',
    DOPPLEGANGER='warband',RAKSHASA='warband',GENIE='warband',DEMONIC='warband',
    IMP='warband',MEPHIT='warband',FAIRY='warband',SOLAR='warband',ANTISOLAR='warband',
    PLANATAR='warband',DARKPLANATAR='warband',MIND_FLAYER='warband',BEHOLDER='warband',
    DRIDER='warband',
}

M.GENERAL_PROFILE={
    HUMANOID='warband',
    GIANTHUMANOID='warband',
    UNDEAD='silent',
    ANIMAL='silent',
    PLANT='silent',
    MONSTER='silent',
}

-- Races that may fall back to M.LINES.DEFAULT when they have no dedicated race table in M.LINES.
M.SPEAKING_RACES={
    HUMAN=true,ELF=true,HALF_ELF=true,DWARF=true,HALFLING=true,GNOME=true,HALFORC=true,
    TIEFLING=true,AASIMAR=true,DUERGAR=true,SVIRFNEBLIN=true,GITHYANKI=true,
    ORC=true,GOBLIN=true,BUGBEAR=true,TASLOI=true,YUANTI=true,DOPPLEGANGER=true,
    RAKSHASA=true,GENIE=true,DEMONIC=true,LICH=true,VAMPIRE=true,VAMPYRE=true,
}

M.LINES={
    HOBGOBLIN={
        {key='hob_1',text='Steel out! Take them!'},
        {key='hob_2',text='Form on me! Intruders!'},
        {key='hob_3',text='Cut them down! Move!'},
        {key='hob_4',text='Blades up! Over here!'},
    },
    GNOLL={
        {key='gnl_1',text='Fresh meat! Pack, to me!'},
        {key='gnl_2',text='Tear them apart! Rrragh!'},
        {key='gnl_3',text='Prey! Surround them!'},
    },
    KOBOLD={
        {key='kob_1',text='Yip! Yip! Intruder - pack, come quick!'},
        {key='kob_2',text='Kill-kill! More sticks and arrows here!'},
        {key='kob_3',text='Aii! Big-folk! Help, help!'},
    },
    XVART={
        {key='xvt_1',text='Eeee! Outsiders! Tribe, come!'},
        {key='xvt_2',text='Stab them! All together!'},
        {key='xvt_3',text='Aiiie! Help us, brothers!'},
    },
    OGRE={
        {key='ogr_1',text='Smash little ones! Come crush!'},
        {key='ogr_2',text='Meat here! Hit them hard!'},
    },
    HALF_OGRE={
        {key='hog_1',text='Over here! Break their bones!'},
        {key='hog_2',text='Crush them! Move in!'},
    },
    OGRILLON={
        {key='ogl_1',text='Smash them flat! Over here!'},
        {key='ogl_2',text='Little meat! Come pound them!'},
    },
    GIBBERLING={
        {key='gib_1',text='*lets out a shrill, chittering shriek*'},
        {key='gib_2',text='*howls in a frenzied chorus*'},
    },
    WOLF={
        {key='wlf_1',text='*lets out a sharp howl*'},
        {key='wlf_2',text='*snarls and howls to the pack*'},
    },
    WORG={
        {key='wrg_1',text='*lets out a deep, hunting howl*'},
        {key='wrg_2',text='*barks a low snarl to the pack*'},
    },
    DOG={
        {key='dog_1',text='*barks furiously*'},
        {key='dog_2',text='*growls and barks an alarm*'},
    },
    DEFAULT={
        {key='war_1',text='To arms! Enemy spotted!'},
        {key='war_2',text='Over here! On me!'},
        {key='war_3',text='We have company - move in!'},
        {key='war_4',text='Blades out! Over here!'},
        {key='war_5',text='Take them down! Quickly!'},
    },
    REPLIES={
        {key='rep_1',text='On my way!'},
        {key='rep_2',text='Hold them - coming!'},
        {key='rep_3',text='Moving in!'},
    },
    CALLOUTS={
        {key='arena_locked',text='Exits sealed while foes remain!'},
        {key='cc_fired',text='Chain Contingency - Fired'},
        {key='ctg_fired',text='Contingency - Fired'},
        {key='msq_fired',text='Minor Sequencer - Fired'},
        {key='seq_fired',text='Spell Sequencer - Fired'},
        {key='trg_fired',text='Spell Trigger - Fired'},
    },
}

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function upper(v) return type(v)=='string' and #v>0 and v:upper() or nil end
local function clampDiff(d)
    if not number(d) then return 3 end
    local n=math.floor(d)
    if n<1 then return 1 elseif n>5 then return 5 end
    return n
end

-- Flat sorted list of {key, text} for installer / test inspection.
function M.allLines()
    local seen,out={},{}
    for _,list in pairs(M.LINES) do
        for _,entry in ipairs(list) do
            if not seen[entry.key] then
                seen[entry.key]=true
                out[#out+1]={key=entry.key,text=entry.text}
            end
        end
    end
    table.sort(out,function(a,b) return a.key<b.key end)
    return out
end

-- Profile name ('silent', 'pack', 'warband', 'map') for actor + optional designer orders.
function M.profileOf(actor,orders)
    if type(orders)=='table' and type(orders.call)=='string' and M.CONFIG.profiles[orders.call] then
        return orders.call
    end
    local race=type(actor)=='table' and upper(actor.race) or nil
    if race and M.RACE_PROFILE[race] then return M.RACE_PROFILE[race] end
    local gen=type(actor)=='table' and upper(actor.general) or nil
    if gen and M.GENERAL_PROFILE[gen] then return M.GENERAL_PROFILE[gen] end
    -- Unlabeled actor (e.g. unit-test humanoids without IDS metadata): warband default.
    if race==nil and gen==nil then return 'warband' end
    return 'silent'
end

local function speaksWords(actor)
    if type(actor)~='table' then return false end
    local race=upper(actor.race)
    local gen=upper(actor.general)
    if race and M.LINES[race] then return true end
    if race and M.SPEAKING_RACES[race] then return true end
    if gen=='HUMANOID' or gen=='GIANTHUMANOID' then return true end
    if race==nil and gen==nil then return true end
    return false
end

local function linePoolFor(actor,profileName)
    if profileName=='silent' then return nil end
    local race=type(actor)=='table' and upper(actor.race) or nil
    if race and M.LINES[race] then return M.LINES[race],race end
    if profileName=='pack' then return M.LINES.WOLF,'PACK' end
    if speaksWords(actor) then return M.LINES.DEFAULT,'DEFAULT' end
    return nil,nil
end

local function pickLine(pool,lastKey,rng)
    if type(pool)~='table' or #pool==0 then return nil end
    if #pool==1 then return pool[1] end
    local candidates={}
    for _,entry in ipairs(pool) do
        if entry.key~=lastKey then candidates[#candidates+1]=entry end
    end
    if #candidates==0 then candidates=pool end
    local idx=1
    if type(rng)=='function' then
        local r=rng()
        if number(r) and r>=0 then
            idx=(math.floor(r*#candidates)%#candidates)+1
        end
    end
    return candidates[idx]
end

-- Per-area stateful call-for-help & shout coordinator.
function M.new(customConfig)
    local cfg={}
    for k,v in pairs(M.CONFIG) do cfg[k]=v end
    if type(customConfig)=='table' then
        for k,v in pairs(customConfig) do cfg[k]=v end
    end
    local profiles=cfg.profiles or M.CONFIG.profiles

    local calledUntil={}
    local alertedUntil={}
    local hopOf={}
    local rootOf={}
    local shoutCooldownUntil={}
    local lastLineByBucket={}
    local lastGlobalShoutTick=nil
    local lastTick=nil
    local counts={calls=0,alerted=0,shouts=0,replies=0}
    local api={}

    local function reset()
        calledUntil,alertedUntil,hopOf,rootOf={},{},{},{}
        shoutCooldownUntil,lastLineByBucket={},{}
        lastGlobalShoutTick,lastTick=nil,nil
    end

    -- Evaluate whether caller alerts nearby allies among members ({id, x, y, race, general, orders}).
    -- Returns {profile, root, alerted={ids...}, shouts={{id, key, text, reply?}, ...}}.
    function api:call(caller,members,difficulty,tick,rng)
        if type(caller)~='table' or caller.id==nil or not number(tick) then
            return {profile='silent',alerted={},shouts={}}
        end
        if lastTick and tick<lastTick then reset() end
        lastTick=tick

        local profileName=M.profileOf(caller,caller.orders)
        local prof=profiles[profileName] or profiles.silent
        if profileName=='silent' then
            return {profile='silent',alerted={},shouts={}}
        end
        if calledUntil[caller.id] and calledUntil[caller.id]>tick then
            return {profile=profileName,root=rootOf[caller.id],alerted={},shouts={}}
        end

        local diff=clampDiff(difficulty)
        local radius=(prof.radiusByDifficulty and prof.radiusByDifficulty[diff]) or 0
        local maxHops=(prof.maxHopsByDifficulty and prof.maxHopsByDifficulty[diff]) or 0
        local alertTicks=math.max(1,math.floor((cfg.alertSeconds or 60)*M.TICKS_PER_SECOND))

        local activeAlert=alertedUntil[caller.id] and alertedUntil[caller.id]>=tick
        local startHop=activeAlert and (hopOf[caller.id] or 0) or 0
        local root=(activeAlert and rootOf[caller.id]) or caller.id
        calledUntil[caller.id]=tick+alertTicks

        if radius<=0 or startHop>maxHops or not (number(caller.x) and number(caller.y)) then
            return {profile=profileName,root=root,alerted={},shouts={}}
        end

        local callerRace=upper(caller.race)
        local visited={[caller.id]=true}
        local queue={{actor=caller,hop=startHop}}
        local head=1
        local alerted={}
        local responder,responderDist=nil,nil

        while head<=#queue do
            local cur=queue[head];head=head+1
            local stepRadius=cur.hop==startHop and radius or math.floor(radius*(cfg.relayRadiusFactor or 0.85))
            for _,m in ipairs(type(members)=='table' and members or {}) do
                if type(m)=='table' and m.id~=nil and not visited[m.id] and number(m.x) and number(m.y) then
                    local alreadyInRoot=alertedUntil[m.id] and alertedUntil[m.id]>=tick and rootOf[m.id]==root
                    local mProfile=M.profileOf(m,m.orders)
                    local targetOk=(prof.sameRaceOnly and mProfile=='pack' and callerRace~=nil and upper(m.race)==callerRace) or
                        (not prof.sameRaceOnly and (mProfile=='warband' or mProfile=='map'))
                    if not alreadyInRoot and targetOk then
                        local d=targeting.distance(cur.actor,m)
                        if d<=stepRadius then
                            visited[m.id]=true
                            alerted[#alerted+1]=m.id
                            hopOf[m.id]=cur.hop+1
                            rootOf[m.id]=root
                            alertedUntil[m.id]=tick+alertTicks
                            if cur.hop==startHop and (responderDist==nil or d<responderDist or (d==responderDist and m.id<responder.id)) then
                                responder,responderDist=m,d
                            end
                            if cur.hop<maxHops then
                                queue[#queue+1]={actor=m,hop=cur.hop+1}
                            end
                        end
                    end
                end
            end
        end

        table.sort(alerted)
        if #alerted==0 then
            return {profile=profileName,root=root,alerted={},shouts={}}
        end

        rootOf[caller.id]=root
        hopOf[caller.id]=startHop
        alertedUntil[caller.id]=tick+alertTicks
        counts.calls=counts.calls+1
        counts.alerted=counts.alerted+#alerted

        local shouts={}
        local minGap=math.floor((cfg.minGlobalShoutGapSeconds or 0)*M.TICKS_PER_SECOND)
        local cooldownTicks=math.floor((prof.cooldownSeconds or 45)*M.TICKS_PER_SECOND)
        local globalReady=lastGlobalShoutTick==nil or (tick-lastGlobalShoutTick)>=minGap
        local rootReady=not shoutCooldownUntil[root] or shoutCooldownUntil[root]<=tick

        if prof.shouts and globalReady and rootReady then
            local pool,bucket=linePoolFor(caller,profileName)
            local chosen=pool and pickLine(pool,lastLineByBucket[bucket],rng) or nil
            if chosen then
                lastLineByBucket[bucket]=chosen.key
                shoutCooldownUntil[root]=tick+cooldownTicks
                lastGlobalShoutTick=tick
                shouts[#shouts+1]={id=caller.id,key=chosen.key,text=chosen.text}
                counts.shouts=counts.shouts+1
                local replyMin=prof.replyMinAlerted or 99
                if #alerted>=replyMin and responder and speaksWords(responder) and profileName~='pack' then
                    local rep=pickLine(M.LINES.REPLIES,lastLineByBucket.REPLIES,rng)
                    if rep then
                        lastLineByBucket.REPLIES=rep.key
                        shouts[#shouts+1]={id=responder.id,key=rep.key,text=rep.text,reply=true}
                        counts.replies=counts.replies+1
                    end
                end
            end
        end

        return {profile=profileName,root=root,alerted=alerted,shouts=shouts}
    end

    function api:invalidate() reset() end
    function api:inspect()
        local out={}
        for k,v in pairs(counts) do out[k]=v end
        return {counts=out}
    end

    return api
end

return M
