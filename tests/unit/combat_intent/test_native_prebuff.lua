-- Native prebuff selection (Prep Phase 2a, combat-intent/prebuff.lua) and timed-span tracking in
-- combat-intent/spells.lua. Plain values and synthetic SPL records; no game files.
local spells=require('combat-intent.spells')
local prebuff=require('combat-intent.prebuff')
local groups=0

local function fx(op,fields)
    local e={opcode=op,target=1,power=0,p1=0,p2=0,timing=0,resist=0,duration=0,prob1=100,prob2=0,res='',
        dice=0,sides=0,save=0,saveBonus=0,special=0}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end

local SINGLE={kind='PRO',resref='SINGLE',type=2,speed=20,flags=0,extFlags=0}
local ALLY_AREA={kind='PRO',resref='ALLY',type=3,speed=20,flags=0,extFlags=0,areaFlags=8,trigger=30,radius=120,coneWidth=0}
local ENEMY_AREA={kind='PRO',resref='ENEMY',type=3,speed=20,flags=0,extFlags=0,areaFlags=16,trigger=30,radius=120,coneWidth=0}

local function spl(resref,level,target,projectile,effects,spellType)
    return {
        kind='SPL',resref=resref,name=0,flags=0,spellType=spellType or 1,exclusion=0,school=0,secondary=0,
        level=level,casting={},
        abilities={{form=1,flags=0,location=2,target=target or 5,targetCount=0,range=target==4 and 30 or 10,
            minLevel=1,speed=1,projectile=projectile or 1,effects=effects}},
    }
end

local SUBS={}
local function lookup(kind,key)
    if kind=='PRO' then
        if key==176 or key==158 then return ALLY_AREA end
        if key==38 then return ENEMY_AREA end
        return SINGLE
    end
    if kind=='ITM' and type(key)=='string' and key:upper()=='FBLADE' then
        return {kind='ITM',resref='FBLADE',flags=0,enchantment=1,itemType=20,equipping={},
            abilities={{form=1,flags=0,location=1,attackType=1,target=1,range=1,speed=2,projectile=1,
                thac0=0,dice=1,sides=8,damageBonus=2,damageType=1,effects={}}}}
    end
    if kind=='SPL' and type(key)=='string' then return SUBS[key:upper()] end
    return nil
end

local function makeRow(resref,rec,ready,list,casterLevel)
    local classified=spells.classify(rec,1,lookup,{level=casterLevel or 9})
    return {resref=resref,list=list or 'mage',level=rec.level,ready=ready or 1,total=ready or 1,spell=classified}
end

-- 1. spells.classify records r.timed even when a timed buff carries permanent helper/removal effects
-- alongside it (Improved Invisibility 138s + permanent visual/removal, Free Action 180s + permanent cure,
-- Haste 72s + instant slow-removal), while an until-struck permanent Stoneskin with timing=1 stays 'long'.
do
    local impInvis=spl('SPWI405',4,1,1,{
        fx(20,{target=2,p2=1,timing=0,duration=138}),
        fx(0,{target=2,p1=4,timing=0,duration=138}),
        fx(215,{target=2,timing=1,res='SPWI405'}),
    })
    local rowImp=makeRow('SPWI405',impInvis,1,'mage',9)
    assert(rowImp.spell.roles.protection.timed==138)
    local ci=prebuff.classify(rowImp)
    assert(ci and ci.phase=='short' and ci.span==138)

    local freeAct=spl('SPPR403',4,1,1,{
        fx(101,{target=2,p2=109,timing=0,duration=180}),
        fx(162,{target=2,timing=1}),
    },2)
    local rowFree=makeRow('SPPR403',freeAct,1,'priest',9)
    assert(rowFree.spell.roles.protection.timed==180)
    local cf=prebuff.classify(rowFree)
    assert(cf and cf.phase=='short' and cf.span==180)

    local haste=spl('SPWI305',3,4,176,{
        fx(16,{target=2,timing=0,duration=72}),
        fx(321,{target=2,timing=1,res='SPWI312'}),
    })
    local rowHaste=makeRow('SPWI305',haste,1,'mage',9)
    local ch=prebuff.classify(rowHaste)
    assert(ch and ch.phase=='short' and ch.point==true and ch.span==72)

    local permSkins=spl('SPWI408P',4,5,1,{fx(218,{target=1,p1=6,timing=1,duration=0})})
    local cp=prebuff.classify(makeRow('SPWI408P',permSkins,1,'mage',9))
    assert(cp and cp.phase=='long' and cp.span==prebuff.CONFIG.longSeconds)
end
groups=groups+1

-- 2. Classification boundaries: long (>= 1800s) vs short (36..1799s) vs strict tactical exclusions
-- (PfMW 24s, Improved Alacrity 12s, Sanctuary, plain Invisibility, Polymorph/Shapechange, Berserk,
-- conjured slot-locking weapons, friendly-fire, attack spells, summons, heals for others, innates).
do
    local stoneskin=makeRow('SPWI408',spl('SPWI408',4,5,1,{fx(218,{p1=5,duration=43200})}),1,'mage')
    local armor=makeRow('SPWI102',spl('SPWI102',1,5,1,{fx(0,{p1=6,p2=16,duration=32400})}),1,'mage')
    local ironSkins=makeRow('SPPR506',spl('SPPR506',5,5,1,{fx(218,{p1=6,duration=43200})}),1,'priest')
    local mirror=makeRow('SPWI212',spl('SPWI212',2,5,1,{fx(119,{p1=5,duration=180})}),1,'mage')
    local shield=makeRow('SPWI114',spl('SPWI114',1,5,1,{fx(0,{p1=4,p2=16,duration=300})}),1,'mage')
    local bless=makeRow('SPPR101',spl('SPPR101',1,4,158,{fx(130,{target=2,duration=36})},2),1,'priest')

    assert(prebuff.classify(stoneskin).phase=='long')
    assert(prebuff.classify(armor).phase=='long')
    assert(prebuff.classify(ironSkins).phase=='long')
    assert(prebuff.classify(mirror).phase=='short')
    assert(prebuff.classify(shield).phase=='short')
    local cb=prebuff.classify(bless)
    assert(cb and cb.phase=='short' and cb.point==true and cb.span==36)

    -- Ultra-short tactical immunities (< 36s) stay in book for live combat.
    local pfmw=makeRow('SPWI611',spl('SPWI611',6,5,1,{fx(120,{p2=1,duration=24})}),1,'mage')
    local alacrity=makeRow('SPWI921',spl('SPWI921',9,5,1,{fx(188,{p1=1,duration=12}),fx(0,{p1=1,duration=60})}),1,'mage')
    assert(select(2,prebuff.classify(pfmw))=='too-short')
    assert(select(2,prebuff.classify(alacrity))=='tactical-form')

    -- Sanctuary, plain invisibility, shapechange, conjured weapon, innate, attack, summon, other-heal.
    local sanctuary=makeRow('SPPR109',spl('SPPR109',1,5,1,{fx(153,{duration=60})},2),1,'priest')
    local plainInvis=makeRow('SPWI206',spl('SPWI206',2,1,1,{fx(20,{target=2,p2=0,duration=3600})}),1,'mage')
    local shapechange=makeRow('SPWI490',spl('SPWI490',4,5,1,{fx(135,{duration=300}),fx(0,{p1=4,duration=300})}),1,'mage')
    local conjWeapon=makeRow('SPPR206',spl('SPPR206',2,5,1,{fx(111,{res='FBLADE',duration=120}),fx(54,{p1=2,duration=120})},2),1,'priest')
    local innateBuff=makeRow('SPIN101',spl('SPIN101',1,5,1,{fx(130,{duration=120})},4),1,'innate')
    local fireball=makeRow('SPWI304',spl('SPWI304',3,4,38,{fx(12,{target=2,dice=6,sides=6})}),1,'mage')
    local summon=makeRow('SPPR301',spl('SPPR301',3,4,158,{fx(130,{target=2,duration=2400})},2),1,'priest')
    summon.spell.roles.summon={who={self=true}}
    local cureOther=makeRow('SPPR103',spl('SPPR103',1,1,1,{fx(17,{target=2,p1=8}),fx(0,{target=2,p1=1,duration=60})},2),1,'priest')

    assert(select(2,prebuff.classify(sanctuary))=='sanctuary')
    assert(select(2,prebuff.classify(plainInvis))=='plain-invisibility')
    assert(select(2,prebuff.classify(shapechange))=='tactical-form')
    assert(select(2,prebuff.classify(conjWeapon))=='tactical-form')
    assert(select(2,prebuff.classify(innateBuff))=='list')
    assert(select(2,prebuff.classify(fireball))=='no-defence')
    assert(select(2,prebuff.classify(summon))=='role-summon')
    assert(select(2,prebuff.classify(cureOther))=='role-heal')
end
groups=groups+1

-- 3. Priority ordering, difficulty caps, deduplication, and skipping already-active buffs.
do
    local skin=makeRow('SPWI408',spl('SPWI408',4,5,1,{fx(218,{p1=5,duration=43200})}),2,'mage')
    local armor=makeRow('SPWI102',spl('SPWI102',1,5,1,{fx(0,{p1=6,p2=16,duration=32400})}),1,'mage')
    local globe=makeRow('SPWI406',spl('SPWI406',4,5,1,{fx(102,{p1=3,duration=180})}),1,'mage')
    local mirror=makeRow('SPWI212',spl('SPWI212',2,5,1,{fx(119,{p1=5,duration=180})}),2,'mage')
    local shield=makeRow('SPWI114',spl('SPWI114',1,5,1,{fx(0,{p1=4,p2=16,duration=300})}),1,'mage')
    local haste=makeRow('SPWI305',spl('SPWI305',3,4,176,{fx(16,{target=2,duration=72})}),1,'mage')

    -- Phase 'long' picks only long buffs, Stoneskin before Armor, deduplicating the 2nd Stoneskin slot.
    local outLong=prebuff.select({spells={armor,skin},difficulty=4,phase='long',caster={state=0,guard={}}})
    assert(#outLong==2 and outLong[1].resref=='SPWI408' and outLong[2].resref=='SPWI102')

    -- Easy difficulty (1) caps maxShort at 0 and maxLong at 1.
    local easy=prebuff.select({spells={armor,skin,globe,mirror,shield,haste},difficulty=1,phase='both',caster={state=0,guard={}}})
    assert(#easy==1 and easy[1].resref=='SPWI408')

    -- Hard difficulty (4) orders long first, then short by tier (globe > mirror > haste > shield).
    local hard=prebuff.select({spells={shield,haste,mirror,globe,armor,skin},difficulty=4,phase='both',caster={state=0,guard={}}})
    assert(#hard==6)
    assert(hard[1].resref=='SPWI408' and hard[2].resref=='SPWI102')
    assert(hard[3].resref=='SPWI406' and hard[4].resref=='SPWI212')
    assert(hard[5].resref=='SPWI305' and hard[6].resref=='SPWI114')

    -- Active Stoneskin, Mirror Image, Haste state, and guard.sources skip redundant recasts; Improved Haste still casts over normal Haste.
    local impHaste=makeRow('SPWI613',spl('SPWI613',6,1,1,{fx(16,{target=2,p2=1,duration=90})}),1,'mage')
    local active=prebuff.select({
        spells={skin,armor,globe,mirror,haste,impHaste,shield},
        difficulty=5,
        phase='both',
        caster={
            state=0x8000, -- STATE_HASTED
            skins=4,
            mirror=3,
            guard={sources={SPWI102=true},recast={SPWI406=60}},
        },
    })
    assert(#active==2 and active[1].resref=='SPWI613' and active[2].resref=='SPWI114')
end
groups=groups+1

-- 4. Designer orders: prep=false, noPrepIn, prepSkip, and slot reservation for opener/talkPrep/prebuff.
do
    local duhm=makeRow('SPPR214',spl('SPPR214',2,5,1,{fx(132,{duration=60})},2),1,'priest')
    local aid=makeRow('SPPR201',spl('SPPR201',2,1,1,{fx(129,{target=2,duration=90})},2),1,'priest')
    local bless=makeRow('SPPR101',spl('SPPR101',1,4,158,{fx(130,{target=2,duration=36})},2),2,'priest')
    local armor=makeRow('SPWI102',spl('SPWI102',1,5,1,{fx(0,{p1=6,p2=16,duration=32400})}),1,'mage')

    -- Drakar reserves his single DUHM slot for his round-1 opener choice from Hard (4), but uses it as a prebuff on Core (3).
    local drakar={opener={{'SPPR208','SPPR214'}},openerFrom=4}
    assert(#prebuff.select({spells={duhm},difficulty=4,phase='both',orders=drakar})==0)
    assert(#prebuff.select({spells={duhm},difficulty=3,phase='both',orders=drakar})==1)

    -- Neira reserves SPPR201 for talkPrep from Hard; Zeela reserves 1 of 2 SPPR101 slots so the spare copy can still fire if needed.
    local neira={talkPrep={{cast='SPPR201',spend='SPPR201'}},talkFrom=4}
    assert(#prebuff.select({spells={aid},difficulty=4,phase='both',orders=neira})==0)
    local zeela={prebuff={{cast='SPPR101',spend='SPPR101'}},prebuffFrom=4}
    assert(#prebuff.select({spells={bless},difficulty=4,phase='both',orders=zeela})==1)

    -- Venkt in BG1901 skips automatic prebuffs (noPrepIn), while in BG1900 he only reserves his single SPWI102 for orders.prebuff.
    local venkt={noPrepIn={'BG1901','AR1901'},prebuff={{cast='SPWI102',spend='SPWI102'}},prebuffFrom=2}
    local mirror=makeRow('SPWI212',spl('SPWI212',2,5,1,{fx(119,{p1=5,duration=180})}),1,'mage')
    assert(#prebuff.select({spells={armor,mirror},difficulty=4,phase='both',orders=venkt,area='bg1901'})==0)
    local outdoor=prebuff.select({spells={armor,mirror},difficulty=4,phase='both',orders=venkt,area='BG1900'})
    assert(#outdoor==1 and outdoor[1].resref=='SPWI212')

    -- prep=false and prepSkip={'prebuff'} or specific resref.
    assert(#prebuff.select({spells={mirror},difficulty=4,phase='both',orders={prep=false}})==0)
    assert(#prebuff.select({spells={mirror},difficulty=4,phase='both',orders={prepSkip={'prebuff'}}})==0)
    assert(#prebuff.select({spells={armor,mirror},difficulty=4,phase='both',orders={prepSkip={'spwi212'}}})==1)
end
groups=groups+1

-- 5. We Overwrite compatibility: modded spells with arbitrary custom resrefs, altered durations, or
-- changed target modes classify purely from their runtime SPL opcodes and durations.
do
    local customLong=makeRow('MODWARD9',spl('MODWARD9',3,5,1,{fx(218,{p1=4,duration=7200})}),1,'mage')
    assert(prebuff.classify(customLong).phase=='long')

    local moddedSkinShort=makeRow('SPWI408',spl('SPWI408',4,5,1,{fx(218,{p1=4,duration=90})}),1,'mage')
    assert(prebuff.classify(moddedSkinShort).phase=='short')

    local moddedMirrorBurst=makeRow('SPWI212',spl('SPWI212',2,5,1,{fx(119,{p1=3,duration=24})}),1,'mage')
    assert(select(2,prebuff.classify(moddedMirrorBurst))=='too-short')
end
groups=groups+1

-- 6. Overnight 12h rest-buff parity (freeRestBuffs): picks free restSpells in phase 'long' / 'both' from
-- difficulty >= 2, spares memorized daytime SPWI408 slots, respects Easy (1), phase 'short', skins > 0,
-- and designer orders (prep=false, noPrepIn, prepSkip).
do
    local skinMem=makeRow('SPWI408',spl('SPWI408',4,5,1,{fx(218,{p1=5,duration=43200})}),1,'mage')
    local armor=makeRow('SPWI102',spl('SPWI102',1,5,1,{fx(0,{p1=6,p2=16,duration=32400})}),1,'mage')
    local restSkin={resref='SPWI408',list='mage',level=4,ready=1,usable=true,free=true,spell=skinMem.spell}

    -- Phase 'long' on Core (3): restSkin wins as free=true and blocks spending the memorized SPWI408 slot!
    local picked=prebuff.select({spells={armor,skinMem},restSpells={restSkin},difficulty=3,phase='long',
        caster={state=0,guard={}}})
    assert(#picked==2 and picked[1].resref=='SPWI408' and picked[1].free==true and picked[2].resref=='SPWI102')

    -- Also eligible in 'both' from Normal (2), never at Easy (1), never in 'short', never when skins > 0.
    local normBoth=prebuff.select({spells={},restSpells={restSkin},difficulty=2,phase='both',caster={state=0,guard={}}})
    assert(#normBoth==1 and normBoth[1].free==true)
    assert(#prebuff.select({spells={},restSpells={restSkin},difficulty=1,phase='long',caster={state=0,guard={}}})==0)
    assert(#prebuff.select({spells={},restSpells={restSkin},difficulty=4,phase='short',caster={state=0,guard={}}})==0)
    assert(#prebuff.select({spells={},restSpells={restSkin},difficulty=4,phase='long',caster={state=0,skins=3,guard={}}})==0)

    -- Respects designer skip controls.
    assert(#prebuff.select({spells={},restSpells={restSkin},difficulty=4,phase='long',orders={prep=false}})==0)
    assert(#prebuff.select({spells={},restSpells={restSkin},difficulty=4,phase='long',orders={noPrepIn={'BG1804'}},area='BG1804'})==0)
    assert(#prebuff.select({spells={},restSpells={restSkin},difficulty=4,phase='long',orders={prepSkip={'SPWI408'}}})==0)
end
groups=groups+1

return groups
