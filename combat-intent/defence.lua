-- The engine's own protections and buffs for one caster (step 3, third slice, D1; DEFENCE-01).
-- Christopher's answers of 2026-10-19: weigh defence against attack every round; protect and
-- buff allies rather like SCS: the caster itself, and areas around it that reach its allies.
-- Single-target spells on allies only as exceptions agreed with him (the profile's allySpells,
-- empty for now), because most of them take long to cast. Casting time counts.
--
-- Inputs are plain values, as for combat-intent/choice.lua: the caster's frame, whose friends
-- (the caster and its allies) carry their armour class and guard (what protects them now) and
-- may carry attack data; the classified ready spells; the profile; the tick and the tick of
-- the caster's last defence. Nothing here touches the engine or raises on odd data.
--
-- Worth is on the attack's scale (shares of a creature):
-- - A protection is worth the share of a friend's hit points it probably saves within the
--   horizon, the kill bonus as far as it keeps the friend alive, and the rounds it keeps the
--   friend in the fight (alive and not disabled), each worth a round of disable. Harm runs over
--   time: Stoneskin's skins and Mirror Images absorb the first hits, so they buy rounds even
--   when the friend falls in the end. What a friend has already counts first; the same kind
--   twice counts once (the larger), independent kinds compound (armour lowers the hits that
--   get past weapon immunity), and a fresh Stoneskin over skins that last the horizon gains
--   nothing: SCS keeps "at least one" up.
-- - A buff is worth the share of an enemy its receivers' extra weapon damage takes. The caster's
--   own weapon does not count; it casts.
-- Harm comes from combat-intent/threat.lua: weapons, spells aimed at one creature, areas and
-- disables, as the caster perceives them.
local targeting=require('combat-intent.targeting')
local threat=require('combat-intent.threat')
local M={}
M.ROUND=6
-- Worth of a round a friend is in the fight, as a share of it (attacks count a hold for the full
-- 18 seconds as 1).
M.disableRound=1/3
-- Share of enemy casters' disables each kind makes up, for immunities to their opcodes.
M.DISABLES={hold=0.25,charm=0.15,confusion=0.1,panic=0.1,sleep=0.05,stun=0.05,feeblemind=0.05,
    death=0.1,petrify=0.05,silence=0.05,slow=0.05}
-- Opcodes whose immunity keeps each kind of disable out.
M.COVERS={[109]='hold',[175]='hold',[185]='hold',[5]='charm',[241]='charm',[128]='confusion',
    [24]='panic',[39]='sleep',[217]='sleep',[45]='stun',[210]='stun',[76]='feeblemind',[13]='death',
    [55]='death',[134]='petrify',[38]='silence',[40]='slow'}
-- Share of enemy spell damage by type, for resistances, while the enemies' spells are unknown.
M.SPELL_TYPES={fire=0.3,cold=0.15,electricity=0.15,acid=0.1,magic=0.2}
M.PHYSICAL={'slashing','crushing','piercing'}
-- Share of spells one school makes up, for an immunity to a school.
M.schoolShare=1/8
-- Share of attackers that do not see invisible creatures.
M.unseeing=0.9
-- A speed point of casting time is a tenth of a round.
M.speedSeconds=0.6
-- Worth of one spell level, times the profile's economy (as for attacks).
M.costPerLevel=0.03
-- Enemy armour class and hit points when no enemy shows them.
M.enemyAc=5
M.enemyHp=60

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end
local function amount(role,label)
    local a=type(role)=='table' and role.amounts
    local v=type(a)=='table' and a[label]
    return number(v) and v or 0
end
-- Opcode 1 counts half attacks from 6 on: 6 is a half, 7 one and a half, up to 10.
function M.attacks(v)
    if not number(v) or v<=0 then return 0 end
    if v>5 and v<=10 then return v-5.5 end
    return v
end

-- What a set of roles (a spell's, or the effects a friend carries) protects against, as plain
-- numbers. Sets of spell levels: all (globes keep out every spell of the level) and personal
-- (deflections, turnings and traps take spells aimed at one creature).
function M.shield(roles)
    local s={stoneskin=0,mirror=0,armor=0,hp=0,mr=0,saves=0,schools=0,resist={},covers={},
        all={},personal={},nonmagical=false,magicalUpTo=0,invisible=false,improved=false,blur=false}
    local p=type(roles)=='table' and roles.protection
    if type(p)=='table' then
        local k=type(p.kinds)=='table' and p.kinds or {}
        if type(p.weapons)=='table' then
            for key,v in pairs(p.weapons) do
                if key==2 then s.nonmagical=true
                elseif key==0 and number(v) then s.magicalUpTo=math.max(s.magicalUpTo,v)
                elseif key==1 then s.magicalUpTo=math.max(s.magicalUpTo,9) end
            end
        end
        if number(p.stoneskin) then s.stoneskin=p.stoneskin end
        if number(p.mirror) then s.mirror=p.mirror end
        -- An armour change without an amount (setting the base armour class) counts as 2.
        if k.armor then local a=amount(p,'armor');s.armor=a>0 and a or 2 end
        s.blur=k.blur==true
        s.invisible=k.invisible==true
        s.improved=k.improvedInvisible==true
        s.mr=amount(p,'magicResistance')
        s.saves=amount(p,'saves')
        if type(p.resist)=='table' then
            for label,v in pairs(p.resist) do if number(v) then s.resist[label]=math.max(s.resist[label] or 0,v) end end
        end
        local immune=type(p.immuneBy)=='table' and p.immuneBy or {}
        for level in pairs(type(immune.levels)=='table' and immune.levels or {}) do
            if number(level) then s.all[level]=true end
        end
        for _,field in ipairs({'deflectBy','bounceBy','trapBy'}) do
            local by=type(p[field])=='table' and p[field].levels
            for top in pairs(type(by)=='table' and by or {}) do
                if number(top) then for level=1,math.min(top,9) do s.personal[level]=true end end
            end
        end
        for _ in pairs(type(immune.schools)=='table' and immune.schools or {}) do s.schools=s.schools+1 end
        for op in pairs(type(immune.opcodes)=='table' and immune.opcodes or {}) do
            local kind=M.COVERS[op]
            if kind then s.covers[kind]=true end
        end
        if k.freeAction then s.covers.hold=true;s.covers.slow=true end
    end
    local b=type(roles)=='table' and roles.buff
    if type(b)=='table' then s.hp=amount(b,'hp') end
    return s
end

-- Two shields as one: the larger of each number, every flag and level of either.
function M.union(a,b)
    local s={resist={},covers={},all={},personal={}}
    for _,k in ipairs({'stoneskin','mirror','armor','hp','mr','saves','schools','magicalUpTo'}) do
        s[k]=math.max(a[k] or 0,b[k] or 0)
    end
    for _,k in ipairs({'nonmagical','invisible','improved','blur'}) do s[k]=a[k] or b[k] or false end
    for _,k in ipairs({'resist','covers','all','personal'}) do
        for key,v in pairs(a[k]) do s[k][key]=v end
        for key,v in pairs(b[k]) do
            if type(v)=='number' then s[k][key]=math.max(s[k][key] or 0,v) else s[k][key]=v end
        end
    end
    return s
end

-- A friend's shield now: its guard's roles, with the engine's counts of Stoneskin skins and
-- Mirror Images, its invisibility and magic resistance. Its armour class already holds the
-- armour bonuses it has, so they do not count again.
function M.held(friend)
    local guard=type(friend)=='table' and type(friend.guard)=='table' and friend.guard or {}
    local s=M.shield(guard.roles)
    s.armor=0
    if number(friend and friend.mr) then s.mr=math.max(s.mr,friend.mr) end
    if number(guard.stoneskins) then s.stoneskin=guard.stoneskins end
    if number(guard.mirror) then s.mirror=guard.mirror end
    if targeting.has(friend and friend.state,targeting.STATE.improvedInvisible) then s.invisible,s.improved=true,true
    elseif targeting.has(friend and friend.state,targeting.STATE.invisible) then s.invisible=true end
    return s
end

-- The share of levels 1 to top in a set, or in either of two.
local function share(set,top,other)
    if top<1 then return 0 end
    local n=0
    for level=1,top do if set[level] or (other and other[level]) then n=n+1 end end
    return n/top
end
-- What shield s keeps away of threat t (threat.picture's entry) over r rounds:
-- - rate: the share of weapon harm it stops while it holds (weapon immunity, armour,
--   invisibility, resistance); independent ways compound;
-- - pool: the hits it absorbs one by one before weapon harm gets through (Stoneskin's skins;
--   each Mirror Image takes an attack);
-- - spell: the hit points of spell harm a round it keeps away; globes and deflections count
--   by the levels they cover together, other ways compound;
-- - personal: the share of aimed spells it keeps away;
-- - disable: the share of disables it keeps away.
function M.blocks(s,t,r)
    local w,sp=t.weapon,t.spell
    local rate,pool=0,0
    if w.attacks>0 then
        local magical=w.magicalAttacks/w.attacks
        local open=1-((s.nonmagical and 1-magical or 0)+magical*clamp(s.magicalUpTo/3,0,1))
        local hit=w.hits/w.attacks
        local bonus=s.armor+(s.blur and 3 or 0)
        if bonus>0 and hit>0 then open=open*math.max(0.05,hit-0.05*bonus)/hit end
        -- Improved Invisibility lasts through attacks; plain invisibility ends with the next cast.
        if s.improved then open=open*(1-M.unseeing)
        elseif s.invisible then open=open*(1-M.unseeing/math.max(r,1)) end
        local physical=0
        for _,label in ipairs(M.PHYSICAL) do physical=physical+clamp((s.resist[label] or 0)/100,0,1) end
        rate=1-open*(1-physical/#M.PHYSICAL)
        pool=s.stoneskin+s.mirror*hit
    end
    local top=math.max(0,math.floor(sp.level+0.5))
    local typed=0
    for label,part in pairs(M.SPELL_TYPES) do typed=typed+part*clamp((s.resist[label] or 0)/100,0,1) end
    local mr=clamp(s.mr/100,0,1)
    local open=(1-typed)*(1-mr)*(1-clamp(s.schools*M.schoolShare,0,1))
    local area=1-open*(1-share(s.all,top))
    local personal=1-open*(1-share(s.all,top,s.personal))
    if s.improved then personal=1-(1-personal)*(1-M.unseeing)
    elseif s.invisible then personal=1-(1-personal)*(1-M.unseeing/math.max(r,1)) end
    local kinds=0
    for kind,part in pairs(M.DISABLES) do if s.covers[kind] then kinds=kinds+part end end
    local free=(1-clamp(kinds,0,1))*(1-share(s.all,top,s.personal))*(1-mr)*(1-clamp(0.05*s.saves,0,0.5))
    if s.improved then free=free*(1-M.unseeing) end
    return {rate=rate,pool=pool,spell=sp.personal*personal+sp.area*area,personal=personal,disable=1-free}
end

-- How harm runs for friend f under threat t with shield s over r rounds: the hit points it has
-- lost by then (temporary hit points go first), the round it dies in (math.huge if it lives
-- through them), and what s blocks. Absorbed hits go first; the rest of the harm runs evenly.
function M.course(s,f,t,r)
    local maxHp=number(f.maxHp) and f.maxHp>0 and f.maxHp or 1
    local left=number(f.hp) and f.hp>0 and f.hp or maxHp
    local b=M.blocks(s,t,r)
    local weapon=t.weapon.hp*(1-b.rate)
    local hits=t.weapon.hits*(1-b.rate)
    local spell=math.max(0,t.spell.hp-b.spell)
    local lasts=0
    if b.pool>0 then lasts=hits>0 and b.pool/hits or math.huge end
    local need=left+s.hp
    local death
    if lasts==math.huge then death=spell>0 and need/spell or math.huge
    elseif spell*lasts>=need then death=need/spell
    elseif spell+weapon>0 then death=lasts+(need-spell*lasts)/(spell+weapon)
    else death=math.huge end
    local harm=spell*r
    if lasts<r then harm=harm+weapon*(r-lasts) end
    return math.max(0,harm-s.hp),death,b
end

-- The expected loss of friend f under threat t with shield s over r rounds, on the attack's
-- scale: the share of its hit points it loses, the kill bonus as likely as it dies, and the
-- rounds it is out of the fight, dead or disabled, each worth a round of disable. A protection
-- that keeps a friend alive for longer is worth the rounds it fights in the meantime.
function M.loss(s,f,t,r,killBonus)
    local maxHp=number(f.maxHp) and f.maxHp>0 and f.maxHp or 1
    local left=number(f.hp) and f.hp>0 and f.hp or maxHp
    local harm,death,b=M.course(s,f,t,r)
    local dies=clamp((harm-0.5*left)/(0.5*left),0,1)
    local alive=math.min(death,r)
    local disabled=t.spell.disable*(1-b.disable)*alive
    return math.min(harm,left)/maxHp+killBonus*dies+M.disableRound*(r-alive+disabled)
end

-- The living enemies' mean armour class and maximum hit points.
local function enemies(frame)
    local ac,hp,n=0,0,0
    for _,e in ipairs(type(frame.enemies)=='table' and frame.enemies or {}) do
        if targeting.alive(e) then
            ac=ac+(number(e.ac) and e.ac or M.enemyAc)
            hp=hp+(number(e.maxHp) and e.maxHp>0 and e.maxHp or M.enemyHp)
            n=n+1
        end
    end
    if n==0 then return M.enemyAc,M.enemyHp,0 end
    return ac/n,hp/n,n
end
-- The share of an enemy a buff's extra weapon damage takes through friend f over r rounds; only
-- friends with attack data and an enemy within a round's walk fight.
function M.offense(buff,f,frame,r)
    if type(buff)~='table' or type(f.attack)~='table' then return 0 end
    local ac,hp,n=enemies(frame)
    if n==0 then return 0 end
    local close=false
    for _,e in ipairs(frame.enemies) do
        if targeting.alive(e) and targeting.distance(e,f)<=threat.reach+threat.stride then close=true;break end
    end
    if not close then return 0 end
    local a=threat.attack({attack=f.attack})
    local k=type(buff.kinds)=='table' and buff.kinds or {}
    local apr=a.apr+M.attacks(amount(buff,'attacks'))
    if k.haste then apr=apr+(k.improvedHaste and a.apr or 1) end
    local bonus=amount(buff,'thac0')+(k.bless and 1 or 0)+(k.aid and 1 or 0)+0.5*(amount(buff,'luck')+(k.chant and 1 or 0))
    local before=a.apr*threat.hitChance(a.thac0,ac)*a.damage
    local after=apr*threat.hitChance(a.thac0-bonus,ac)*(a.damage+amount(buff,'damage'))
    return math.max(0,after-before)*r/hp
end

-- Whether a role of a beneficial spell reaches friends: the caster, its area (an area that
-- spares allies does not), or the creature it is cast at.
local function forFriends(role)
    if type(role)~='table' or type(role.who)~='table' then return false end
    if role.who.self or role.who.target then return true end
    if role.who.area then
        local f=role.filters
        return type(f)~='table' or f.allies==true or f.all==true
    end
    return false
end
-- Harm a spell does to friends: damage or disables that reach the caster or its allies.
local function harmsFriends(spell)
    for _,name in ipairs({'damage','disable'}) do
        local r=spell.roles[name]
        if type(r)=='table' and type(r.who)=='table' then
            if r.who.self or r.who.party or r.who.everyone or r.who.casterGroup then return true end
            if r.who.area and type(r.filters)=='table' and (r.filters.allies or r.filters.all) then return true end
        end
    end
    return false
end
-- The protection and buff roles a spell gives its receivers, or nil and why it is no defence.
function M.defence(spell)
    if type(spell)~='table' or type(spell.roles)~='table' then return nil,'unclassified' end
    if spell.partial then return nil,'partial' end
    local p,b=spell.roles.protection,spell.roles.buff
    local gives=forFriends(p) or forFriends(b)
    if not gives then return nil,'no-defence' end
    if harmsFriends(spell) then return nil,'harms-friends' end
    -- Attacks with a protection on the side stay attacks (combat-intent/choice.lua).
    for _,name in ipairs({'damage','disable'}) do
        local r=spell.roles[name]
        if type(r)=='table' and type(r.who)=='table' and (r.who.target or r.who.point) then return nil,'attack' end
    end
    for _,name in ipairs({'summon','heal','raise','removal'}) do
        local r=spell.roles[name]
        if type(r)=='table' and type(r.who)=='table' and next(r.who) then return nil,'role-'..name end
    end
    return {protection=forFriends(p) and p or nil,buff=forFriends(b) and b or nil}
end

local function seconds(role)
    local d=type(role)=='table' and role.duration
    if d=='permanent' or d=='equipped' then return math.huge end
    return number(d) and d or 0
end
local function guarded(friend,resref)
    local guard=type(friend.guard)=='table' and friend.guard or {}
    return (type(guard.recast)=='table' and guard.recast[resref]) or (type(guard.sources)=='table' and guard.sources[resref])
end

-- Who the spell reaches, aimed as it is cast: the caster for a spell on itself, the friends
-- within the area around the caster or a point, an ally an exception names.
local function receivers(input,row,spell,aim)
    local frame=input.frame
    local out={}
    local area=spell.area
    if aim.point and area and number(area.radius) then
        for _,f in ipairs(threat.friends(frame)) do
            if targeting.distance(aim.point,f)<=area.radius then out[#out+1]=f end
        end
        return out
    end
    if aim.friend then out[1]=aim.friend end
    return out
end
-- Where a defence can be cast: on the caster itself (also an area around it); at the caster's
-- spot or an ally's for a spell aimed at a point; at an ally for an agreed exception.
local function aims(input,row,spell)
    local frame=input.frame
    local caster=frame.self
    local out={}
    local range=(number(spell.range) and spell.range or 0)*targeting.rangeUnit
    if spell.target=='self' then
        out[1]={self=true,friend=caster,point=spell.area and {x=caster.x,y=caster.y} or nil}
    elseif spell.target=='point' and spell.area then
        out[1]={point={x=caster.x,y=caster.y}}
        for _,f in ipairs(threat.friends(frame)) do
            if f~=caster and targeting.distance(caster,f)<=range then out[#out+1]={point={x=f.x,y=f.y}} end
        end
    elseif spell.target=='creature' then
        out[1]={self=true,friend=caster}
        local allowed=type(input.mind.allySpells)=='table' and input.mind.allySpells[row.resref]
        if allowed then
            for _,f in ipairs(threat.friends(frame)) do
                if f~=caster and targeting.distance(caster,f)<=range then out[#out+1]={friend=f} end
            end
        end
    end
    return out
end

-- Whether the caster is in acute danger: what it would lose in a round, with what protects it
-- now, reaches mind.acute of the hit points it has left.
function M.acute(input,pictures)
    local caster=input.frame.self
    local t=pictures[caster.id]
    if not t or not number(input.mind.acute) then return false end
    local left=number(caster.hp) and caster.hp>0 and caster.hp or 1
    return (M.course(M.held(caster),caster,t,1))>=input.mind.acute*left
end
-- The chance the caster finishes a cast of the given seconds: each hit or aimed spell that gets
-- through what protects it now can break the cast; absorbed hits do not.
function M.through(input,t,cast)
    if not t or cast<=0 then return 1 end
    local b=M.blocks(M.held(input.frame.self),t,1)
    local part=cast/M.ROUND
    local hits=math.max(0,t.weapon.hits*(1-b.rate)*part-b.pool)
    return math.exp(-hits-t.spell.casters*threat.personal*(1-b.personal)*part)
end

-- Every defence option the caster has: {resref, kind='defence', mode, worth, cost, score, hits
-- (the friends it reaches), slack=0, and self, point or target as the cast is aimed}. rejected
-- (optional) counts why ready defensive spells gave none. A defence that follows the last one
-- within mind.redefend seconds waits, as SCS's does, unless the caster is in acute danger.
function M.options(input,rejected)
    local out={}
    local function reject(why) if rejected then rejected[why]=(rejected[why] or 0)+1 end end
    local mind=input.mind
    local frame=input.frame
    if type(frame)~='table' or type(frame.self)~='table' or type(mind)~='table' then return out end
    local pictures=threat.picture(frame)
    local pause=number(mind.redefend) and mind.redefend or 0
    local waiting=number(input.lastDefence) and number(input.tick) and input.tick-input.lastDefence<pause*15
        and not M.acute(input,pictures)
    local horizon=number(mind.horizon) and mind.horizon or 18
    local killBonus=number(mind.killBonus) and mind.killBonus or 0
    local held={}
    local function heldOf(f) held[f.id]=held[f.id] or M.held(f);return held[f.id] end
    local caster=frame.self
    local ct=pictures[caster.id]
    for _,row in ipairs(type(input.spells)=='table' and input.spells or {}) do
        if type(row)=='table' and number(row.ready) and row.ready>0 and row.usable then
            local spell=row.spell
            local gives,why=M.defence(spell)
            if not gives then
                if why~='no-defence' and why~='attack' and why~='unclassified' then reject(why) end
            elseif waiting then reject('redefend')
            else
                local shield=M.shield(gives)
                local length=math.max(seconds(gives.protection),seconds(gives.buff))
                local rounds=math.min(horizon,length)/M.ROUND
                local best
                for _,aim in ipairs(aims(input,row,spell)) do
                    local worth,hits=0,{}
                    for _,f in ipairs(receivers(input,row,spell,aim)) do
                        if not guarded(f,row.resref) then
                            local t=pictures[f.id]
                            local gain=0
                            if t and rounds>0 then
                                local now=heldOf(f)
                                gain=M.loss(now,f,t,rounds,killBonus)-M.loss(M.union(now,shield),f,t,rounds,killBonus)
                            end
                            if f~=caster then gain=gain+M.offense(gives.buff,f,frame,rounds) end
                            if gain>0 then worth=worth+gain;hits[#hits+1]=f.id end
                        end
                    end
                    if worth>0 and (not best or worth>best.worth) then best={aim=aim,worth=worth,hits=hits} end
                end
                if not best then reject('no-worth')
                else
                    -- Casting time: harm while casting can interrupt the cast; long casts also cost.
                    local cast=(number(spell.speed) and spell.speed or 0)*M.speedSeconds
                    local through=M.through(input,ct,cast)
                    local level=number(row.level) and row.level or number(spell.level) and spell.level or 1
                    local cost=(number(mind.economy) and mind.economy or 1)*M.costPerLevel*level+
                        (number(mind.castCost) and mind.castCost or 0)*cast
                    local worth=best.worth*through*(number(mind.caution) and mind.caution or 1)
                    local option={resref=row.resref,kind='defence',worth=worth,cost=cost,score=worth-cost,
                        hits=best.hits,slack=0}
                    local aim=best.aim
                    if aim.self then option.self=true;option.mode='self'
                    elseif aim.friend then option.target=aim.friend.id;option.mode='ally'
                    else option.point={x=math.floor(aim.point.x+0.5),y=math.floor(aim.point.y+0.5)};option.mode='point' end
                    out[#out+1]=option
                end
            end
        end
    end
    return out
end
return M
