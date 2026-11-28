-- Native contingencies, chain contingencies, sequencers and spell triggers (Prep Phase 2b,
-- combat-intent/contingency.lua). Plain values and synthetic SPL records; no game files.
local spells=require('combat-intent.spells')
local contingency=require('combat-intent.contingency')
local groups=0

local function fx(op,fields)
    local e={opcode=op,target=1,power=0,p1=0,p2=0,timing=0,resist=0,duration=0,prob1=100,prob2=0,res='',
        dice=0,sides=0,save=0,saveBonus=0,special=0}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end

local SINGLE={kind='PRO',resref='SINGLE',type=2,speed=20,flags=0,extFlags=0}
local ALLY_AREA={kind='PRO',resref='ALLY',type=3,speed=20,flags=0,extFlags=0,areaFlags=64+128,trigger=30,radius=120,coneWidth=0}
local PARTY_SAFE_AREA={kind='PRO',resref='ENEMY',type=3,speed=20,flags=0,extFlags=0,areaFlags=64,trigger=30,radius=120,coneWidth=0}
local UNSAFE_AREA={kind='PRO',resref='UNSAFE',type=3,speed=20,flags=0,extFlags=0,areaFlags=0,trigger=30,radius=120,coneWidth=0}

local RECORDS={}
local function spl(resref,level,target,projectile,effects,spellType)
    local rec={
        kind='SPL',resref=resref:upper(),name=0,flags=0,spellType=spellType or 1,exclusion=0,school=0,secondary=0,
        level=level,casting={},
        abilities={{form=1,flags=0,location=2,target=target or 5,targetCount=0,range=target==5 and 0 or 30,
            minLevel=1,speed=1,projectile=projectile or 1,effects=effects}},
    }
    RECORDS[rec.resref]=rec
    return rec
end

local function lookup(kind,key)
    if kind=='PRO' then
        if key==176 then return ALLY_AREA end
        if key==99 then return PARTY_SAFE_AREA end
        if key==38 then return UNSAFE_AREA end
        return SINGLE
    end
    if kind=='ITM' and type(key)=='string' and key:upper()=='FBLADE' then
        return {kind='ITM',resref='FBLADE',flags=0,enchantment=1,itemType=20,equipping={},
            abilities={{form=1,flags=0,location=1,attackType=1,target=1,range=1,speed=2,projectile=1,
                thac0=0,dice=1,sides=8,damageBonus=2,damageType=1,effects={}}}}
    end
    if kind=='CRE' and type(key)=='string' and key:upper()=='MORDY01' then
        return {kind='CRE',resref='MORDY01',level1=12,hp=60,ac=0,thac0=8,apr=2,flags=0,general=1,race=1,class=1,gender=6}
    end
    if kind=='EFF' and type(key)=='string' and key:upper()=='MORDYEFF' then
        return {kind='EFF',effect=fx(67,{target=1,duration=60,res='MORDY01'})}
    end
    if kind=='SPL' and type(key)=='string' then return RECORDS[key:upper()] end
    return nil
end

local function row(resref,rec,ready,list,casterLevel)
    local c=spells.classify(rec,contingency.abilityIndex(rec,casterLevel or 18),lookup,{level=casterLevel or 18})
    return {resref=resref:upper(),list=list or 'mage',level=rec.level,ready=ready or 1,memorized=ready or 1,spell=c}
end

-- Core synthetic wizard spellbook.
local rArmor=spl('SPWI102',1,5,1,{fx(0,{p1=6,p2=16,duration=32400})})
local rMissile=spl('SPWI112',1,1,1,{fx(12,{target=2,p2=64*65536,dice=5,sides=4})})
local rMirror=spl('SPWI212',2,5,1,{fx(119,{p1=5,duration=180})})
local rAcid=spl('SPWI211',2,1,1,{fx(12,{target=2,p2=1*65536,dice=2,sides=4})})
local rRemove=spl('SPWI302',3,1,99,{fx(58,{target=2,p2=1})})
local rFlame=spl('SPWI303',3,1,1,{fx(12,{target=2,p2=8*65536,dice=10,sides=6})})
local rFireball=spl('SPWI304',3,4,38,{fx(12,{target=2,p2=8*65536,dice=10,sides=6})})
local rHaste=spl('SPWI305',3,4,176,{fx(16,{target=2,duration=72})})
local rSkin=spl('SPWI408',4,5,1,{fx(218,{p1=8,duration=43200})})
local rGlobe=spl('SPWI406',4,5,1,{fx(102,{p1=3,duration=180})})
local rBreach=spl('SPWI513',5,1,1,{fx(221,{target=2,p1=9,p2=7})})
local rPfmw=spl('SPWI611',6,5,1,{fx(120,{p2=1,duration=24})})
local rAcidFog=spl('SPWI614',6,1,1,{fx(12,{target=2,p2=1*65536,dice=12,sides=6})})
local rMordy=spl('SPWI716',7,4,1,{fx(177,{target=1,p2=2,duration=60,res='MORDYEFF'})})
local rWilting=spl('SPWI812',8,4,99,{fx(12,{target=2,p2=64*65536,dice=20,sides=8,save=1})})

-- 1. Level/difficulty progression, floor(level/3) Contingency spell-level cap, zero slot debit,
-- and synthetic release spells (c.release == true, nativeSubs).
do
    local book6={row('SPWI112',rMissile,2,'mage',6),row('SPWI212',rMirror,1,'mage',6),row('SPWI211',rAcid,1,'mage',6)}
    local out6=contingency.build({level=6,difficulty=4,spells=book6,lookup=lookup})
    assert(out6.contingency==nil and out6.chain==nil and #out6.sequencers==0)

    -- Level 7 on Normal (2): Minor Sequencer (2x Acid Arrow), no Contingency yet; input ready counts untouched!
    local book7={row('SPWI112',rMissile,2,'mage',7),row('SPWI212',rMirror,1,'mage',7),row('SPWI211',rAcid,1,'mage',7)}
    local out7=contingency.build({level=7,difficulty=2,spells=book7,lookup=lookup})
    assert(out7.contingency==nil and out7.chain==nil and #out7.sequencers==1)
    local ms=out7.sequencers[1]
    assert(ms.tier=='minor' and ms.resref=='BGSE#MS' and ms.callout=='msq_fired' and ms.selfOnly==false)
    assert(#ms.subs==2 and ms.subs[1]=='SPWI211' and ms.subs[2]=='SPWI211')
    assert(ms.spell.release==true and ms.spell.roles.damage~=nil and ms.spell.nativeSubs[1]=='SPWI211')
    assert(book7[1].ready==2 and book7[2].ready==1 and book7[3].ready==1)

    -- Easy difficulty (1): no automatic contingencies or sequencers.
    local easy=contingency.build({level=20,difficulty=1,spells=book7,lookup=lookup})
    assert(easy.contingency==nil and easy.chain==nil and #easy.sequencers==0)

    -- Level 12: floor(12/3)==4 -> Stoneskin (lvl 4) qualifies for Contingency, PfMW (lvl 6) is above cap!
    local book12={row('SPWI408',rSkin,1,'mage',12),row('SPWI611',rPfmw,1,'mage',12),row('SPWI211',rAcid,1,'mage',12)}
    local out12=contingency.build({level=12,difficulty=3,spells=book12,lookup=lookup})
    assert(out12.contingency and out12.contingency.condition=='emergency' and out12.contingency.callout=='ctg_fired')
    assert(out12.contingency.spells[1].resref=='SPWI408' and out12.contingency.spells[1].delivery=='self')
    assert(out12.chain==nil and #out12.sequencers==1)

    -- Level 14 -> Minor + Spell Sequencer; Level 16 -> Minor + Sequencer + Trigger; Level 18 -> + PfMW Contingency + Chain!
    local book18={
        row('SPWI102',rArmor,1,'mage',18),row('SPWI212',rMirror,1,'mage',18),row('SPWI211',rAcid,1,'mage',18),
        row('SPWI303',rFlame,1,'mage',18),row('SPWI408',rSkin,1,'mage',18),row('SPWI406',rGlobe,1,'mage',18),
        row('SPWI611',rPfmw,1,'mage',18),row('SPWI614',rAcidFog,1,'mage',18),row('SPWI716',rMordy,1,'mage',18),
        row('SPWI812',rWilting,1,'mage',18),
    }
    -- Core (3): Chain Contingency uses ward + summons (no offensive chain until Hard/4).
    local core18=contingency.build({level=18,difficulty=3,spells=book18,lookup=lookup})
    assert(core18.contingency.spells[1].resref=='SPWI611')
    assert(core18.chain and core18.chain.condition=='seen' and core18.chain.callout=='cc_fired' and #core18.chain.spells==3)
    assert(core18.chain.spells[1].resref=='SPWI408' and core18.chain.spells[1].delivery=='self')
    assert(core18.chain.spells[2].resref=='SPWI716' and core18.chain.spells[2].delivery=='feet')
    assert(core18.chain.spells[3].resref=='SPWI716')
    assert(#core18.sequencers==3)
    assert(core18.sequencers[1].resref=='BGSE#MS' and core18.sequencers[2].resref=='BGSE#SQ' and core18.sequencers[3].resref=='BGSE#TG')

    -- Hard (4): Chain Contingency upgrades to ward + 2x party-safe Horrid Wilting ('enemy' delivery)!
    local hard18=contingency.build({level=18,difficulty=4,spells=book18,lookup=lookup})
    assert(hard18.chain.condition=='seen' and hard18.chain.spells[1].resref=='SPWI408')
    assert(hard18.chain.spells[2].resref=='SPWI812' and hard18.chain.spells[2].delivery=='enemy')
    assert(hard18.chain.spells[3].resref=='SPWI812' and hard18.chain.spells[3].delivery=='enemy')
end
groups=groups+1

-- 2. Party-safe filtering (indiscriminate Fireball rejected), pure dispel rejection (Remove Magic
-- never auto-built, Breach allowed), defensive sequencer fallback, and unusable package spells.
do
    local unsafeBook={
        row('SPWI212',rMirror,1,'mage',18),
        row('SPWI102',rArmor,1,'mage',18),
        row('SPWI302',rRemove,1,'mage',18),
        row('SPWI304',rFireball,1,'mage',18),
        row('SPWI408',rSkin,1,'mage',18),
        row('SPWI611',rPfmw,1,'mage',18),
    }
    local out=contingency.build({level=18,difficulty=5,spells=unsafeBook,lookup=lookup})
    -- Neither Fireball (harms allies) nor Remove Magic (pure dispel) may enter Chain Contingency or Sequencers!
    -- Chain falls back to pure defensive wards on 'hp50'; Minor Sequencer falls back to self-wards (Mirror + Armor)!
    assert(out.chain and out.chain.condition=='hp50')
    for _,s in ipairs(out.chain.spells) do
        assert(s.resref~='SPWI304' and s.resref~='SPWI302')
    end
    assert(#out.sequencers>=1)
    local ms=out.sequencers[1]
    assert(ms.tier=='minor' and ms.selfOnly==true and ms.spell.release==true)
    assert((ms.subs[1]=='SPWI212' and ms.subs[2]=='SPWI102') or (ms.subs[1]=='SPWI102' and ms.subs[2]=='SPWI212'))

    -- Breach (protection strip, not pure dispel) IS valid in Spell Trigger and outscores a lvl-2 bolt!
    local breachBook={row('SPWI211',rAcid,1,'mage',16),row('SPWI513',rBreach,1,'mage',16),row('SPWI611',rPfmw,1,'mage',16)}
    local outBreach=contingency.build({level=16,difficulty=4,spells=breachBook,lookup=lookup})
    local trg=outBreach.sequencers[#outBreach.sequencers]
    assert(trg and trg.tier=='trigger' and trg.subs[1]=='SPWI513' and trg.selfOnly==false)

    -- Conjured slot-locking weapons and Sanctuary are rejected from defensive Contingency.
    local rConj=spl('SPWI299',2,5,1,{fx(111,{res='FBLADE',duration=120}),fx(0,{p1=4,duration=120})})
    local rSanc=spl('SPWI199',1,5,1,{fx(153,{duration=60})})
    local conjOut=contingency.build({level=12,difficulty=4,spells={row('SPWI299',rConj,1,'mage',12),row('SPWI199',rSanc,1,'mage',12)},lookup=lookup})
    assert(conjOut.contingency==nil)
end
groups=groups+1

-- 3. Challenge-Mode rule (defensiveContingenciesOnly=true): forbids damage, disable, debuff and
-- removal in both automatic and explicit Contingencies / Chain Contingencies, while keeping
-- offensive Sequencers and Spell Triggers intact!
do
    local book={
        row('SPWI211',rAcid,1,'mage',18),row('SPWI302',rRemove,1,'mage',18),
        row('SPWI408',rSkin,1,'mage',18),row('SPWI611',rPfmw,1,'mage',18),
        row('SPWI716',rMordy,1,'mage',18),row('SPWI812',rWilting,1,'mage',18),
    }
    local ch=contingency.build({
        level=18,difficulty=5,spells=book,lookup=lookup,
        config={defensiveContingenciesOnly=true},
    })
    assert(ch.contingency and ch.contingency.spells[1].resref=='SPWI611')
    assert(ch.chain and ch.chain.condition=='seen')
    for _,s in ipairs(ch.chain.spells) do
        assert(not contingency.isOffensive(s.spell),s.resref)
    end
    assert(ch.chain.spells[2].resref=='SPWI716')
    -- Minor Sequencer still holds offensive 2x Acid Arrow!
    assert(ch.sequencers[1].tier=='minor' and ch.sequencers[1].subs[1]=='SPWI211')

    -- Explicit orders trying to sneak Horrid Wilting or Remove Magic into Contingency / Chain are filtered out!
    local explicitFiltered=contingency.build({
        level=18,difficulty=5,spells=book,lookup=lookup,
        orders={
            contingency={spell='SPWI302',condition='seen'},
            chain={spells={'SPWI812','SPWI408','SPWI302'},condition='seen'},
        },
        config={defensiveContingenciesOnly=true},
    })
    assert(explicitFiltered.contingency==nil)
    assert(explicitFiltered.chain and #explicitFiltered.chain.spells==1 and explicitFiltered.chain.spells[1].resref=='SPWI408')
end
groups=groups+1

-- 4. Existing SCS innates (DW#MS0, DW#SQ0, DW#TG0, DW#DT0, DW#DT11), designer orders (prep=false,
-- noPrepIn, prepSkip, explicit contingency/chain/sequencers via lookup), and We Overwrite runtime classification.
do
    local book={
        row('SPWI211',rAcid,1,'mage',18),row('SPWI303',rFlame,1,'mage',18),
        row('SPWI408',rSkin,1,'mage',18),row('SPWI611',rPfmw,1,'mage',18),
        row('SPWI614',rAcidFog,1,'mage',18),row('SPWI812',rWilting,1,'mage',18),
    }
    -- Existing DW#MS0 and DW#DT0 suppress duplicate minor & trigger auto-builds while keeping sequencer!
    local coex=contingency.build({
        level=18,difficulty=4,spells=book,
        innates={['DW#MS0']=true,['DW#DT0']=true},
        lookup=lookup,
    })
    assert(#coex.sequencers==1 and coex.sequencers[1].tier=='sequencer')

    -- Explicit designer orders override innate coexistence and resolve unmemorized spells via lookup!
    local custom=contingency.build({
        level=10,difficulty=1,spells={},
        innates={['DW#MS0']=true},
        orders={
            contingency={spell='SPWI408',condition='hp75'},
            chain={spells={'SPWI305','SPWI812'},condition='seen'},
            sequencers={minor={'SPWI112','SPWI112'}},
        },
        lookup=lookup,
    })
    assert(custom.contingency and custom.contingency.condition=='hp75' and custom.contingency.spells[1].resref=='SPWI408')
    assert(custom.chain and #custom.chain.spells==2 and custom.chain.spells[1].delivery=='feet' and custom.chain.spells[2].delivery=='enemy')
    assert(#custom.sequencers==1 and custom.sequencers[1].subs[1]=='SPWI112')

    -- Area / prep holds suppress Phase 2b packages cleanly.
    local blocked=contingency.build({level=18,difficulty=5,spells=book,orders={noPrepIn={'BG1901'}},area='bg1901',lookup=lookup})
    assert(blocked.contingency==nil and blocked.chain==nil and #blocked.sequencers==0)
    local skipChain=contingency.build({level=18,difficulty=5,spells=book,orders={prepSkip={'chain'},sequencers=false},lookup=lookup})
    assert(skipChain.contingency~=nil and skipChain.chain==nil and #skipChain.sequencers==0)

    -- We Overwrite: if a mod rewrites SPWI302 from Remove Magic into a single-target enemy damage bolt,
    -- contingency.build classifies the modified runtime record instead of assuming SPWI302 is dispel!
    local modded302=spl('SPWI302M',3,1,1,{fx(12,{target=2,p2=8*65536,dice=12,sides=8})})
    local moddedOut=contingency.build({level=14,difficulty=4,spells={row('SPWI302M',modded302,1,'mage',14)},lookup=lookup})
    assert(#moddedOut.sequencers==1 and moddedOut.sequencers[1].tier=='sequencer' and moddedOut.sequencers[1].subs[1]=='SPWI302M')
end
groups=groups+1

-- 5. Pure 0.00s trigger evaluation (M.shouldTrigger), including Guardrail #1 (dead / one-shotted
-- mages never fire threshold contingencies!).
do
    local seen={condition='seen'}
    local hp75={condition='hp75'}
    local hp50={condition='hp50'}
    local emerg={condition='emergency'}

    -- Guardrail #1: alive ~= true NEVER fires, even at 0% HP with enemies right on top!
    assert(contingency.shouldTrigger(emerg,{alive=false,enemiesSeen=3,hpPct=0,nearestEnemyDist=20,skins=0,weaponWard=false})==false)
    assert(contingency.shouldTrigger(seen,{alive=false,enemiesSeen=1,hpPct=100})==false)
    assert(contingency.shouldTrigger(seen,{alive=true,enemiesSeen=0,hpPct=10})==false)
    assert(contingency.shouldTrigger(nil,{alive=true,enemiesSeen=1})==false)
    assert(contingency.shouldTrigger(seen,nil)==false)

    -- 'seen', 'hp75', 'hp50' exact boundaries.
    assert(contingency.shouldTrigger(seen,{alive=true,enemiesSeen=1,hpPct=100})==true)
    assert(contingency.shouldTrigger(hp75,{alive=true,enemiesSeen=1,hpPct=76})==false)
    assert(contingency.shouldTrigger(hp75,{alive=true,enemiesSeen=1,hpPct=75})==true)
    assert(contingency.shouldTrigger(hp50,{alive=true,enemiesSeen=1,hpPct=51})==false)
    assert(contingency.shouldTrigger(hp50,{alive=true,enemiesSeen=1,hpPct=50})==true)

    -- 'emergency': waits while Stoneskin or weaponWard holds above 50% HP, fires immediately in 0.00s
    -- when HP drops <= 50% OR when an unwarded mage has an enemy within closeThreatRange (180)!
    assert(contingency.shouldTrigger(emerg,{alive=true,enemiesSeen=2,hpPct=90,nearestEnemyDist=60,skins=4,weaponWard=false})==false)
    assert(contingency.shouldTrigger(emerg,{alive=true,enemiesSeen=2,hpPct=90,nearestEnemyDist=60,skins=0,weaponWard=true})==false)
    assert(contingency.shouldTrigger(emerg,{alive=true,enemiesSeen=2,hpPct=90,nearestEnemyDist=181,skins=0,weaponWard=false})==false)
    assert(contingency.shouldTrigger(emerg,{alive=true,enemiesSeen=2,hpPct=90,nearestEnemyDist=180,skins=0,weaponWard=false})==true)
    assert(contingency.shouldTrigger(emerg,{alive=true,enemiesSeen=2,hpPct=50,nearestEnemyDist=400,skins=6,weaponWard=true})==true)
end
groups=groups+1

return groups
