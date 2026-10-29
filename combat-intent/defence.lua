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
-- - A buff is worth the share of an enemy its receivers' extra weapon damage takes: more attacks,
--   hits, damage and critical hits, more strength by the game's strength tables (the giant strength
--   potions), less what the spell puts on its own receiver (Whirlwind Attack's penalties), and what
--   its on-hit effects do on the hits they land (F2a: Smite Evil's first hit, every hit of a
--   poisoned blade). A haste the receiver has already adds nothing. The caster's own weapon counts
--   only when its profile fights with it (mind.ownWeapon: fighters and monsters); a caster that
--   casts does not swing. A buff adds to its receivers' fight over the rest of the fight
--   (threat.rest, at most the profile's fightCap) as long as it lasts, as a summons does
--   (combat-intent/summons.lua): drunk or cast early it counts much, late little (lab batch J: SCS's
--   fighters drink their Oil of Speed and giant strength at the start). A protection counts over the
--   horizon, against the harm the caster sees now.
-- Harm comes from combat-intent/threat.lua: weapons, spells aimed at one creature, areas and
-- disables, as the caster perceives them.
-- In the caster's own Time Stop (D2a) nothing threatens it until time resumes: a cast that ends
-- within the stop cannot be broken, and a protection counts only for what is left of it then. The
-- same holds while its side awaits foes out of play (input.calm: the seconds until the first is
-- likely back, combat-intent/choice.lua's readiness), against those foes as they will stand when
-- back; an area weakens none of them meanwhile.
local targeting=require('combat-intent.targeting')
local threat=require('combat-intent.threat')
local openers=require('combat-intent.openers')
local weapons=require('combat-intent.weapons')
local spells=require('combat-intent.spells')
local harm=require('combat-intent.harm')
local arsenal=require('combat-intent.arsenal')
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
-- Share of the harm from enemies that do not see invisible creatures that invisibility keeps away
-- (areas and answers such as True Seeing still find some).
M.unseeing=0.9
-- A speed point of casting time is 10 game ticks, two thirds of a second (ACT-05: the casting
-- action ended 10, 40 and 60 ticks after it began at speeds 1, 4 and 6).
M.speedSeconds=10/15
-- Worth of one spell level, times the profile's economy (as for attacks); a potion costs as a
-- first-level spell.
M.costPerLevel=0.03
M.itemLevel=1
-- Enemy armour class and hit points when no enemy shows them.
M.enemyAc=5
M.enemyHp=60
-- Critical hits: the share of enemies whose helmets do not keep them from doubling a hit. Rough on
-- purpose while the engine does not read their helmets; the lab tunes it.
M.critOpen=0.5
-- The damage types opcode 332 raises (its parameter 2) for each kind of weapon damage; 0 raises all.
M.PERCENT_TYPES={slashing=7,piercing=8,crushing=9,missile=10}

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
-- The seconds nothing threatens the caster's side (see the top): the rest of its own Time Stop, or
-- the calm before foes out of play are back, whichever is longer; nil when neither holds.
local function quiet(input)
    local stop=openers.ownStop(input)
    local calm=number(input.calm) and input.calm>0 and input.calm or nil
    if stop and calm then return math.max(stop,calm) end
    return stop or calm
end
-- The share of a spell slot's cost that counts now (combat-intent/choice.lua, M.slotShare).
local function slots(input) return number(input.slots) and input.slots or 1 end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end
local function amount(role,label)
    local a=type(role)=='table' and role.amounts
    local v=type(a)=='table' and a[label]
    return number(v) and v or 0
end
-- Opcode 1 counts half attacks from 6 on: 6 is a half, 7 one and a half, up to 10.
M.attacks=threat.attacks

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

-- The share of harm invisibility keeps away: M.unseeing of what does not come from enemies that
-- see invisible creatures (threat.picture's seeing). A friend hidden now meets only enemies that
-- see it, so what hides it keeps nothing more away; all of it when seeing is not known.
local function unseen(total,seeing)
    if not number(total) or total<=0 then return M.unseeing end
    return M.unseeing*clamp(1-(number(seeing) and seeing or 0)/total,0,1)
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
        local hidden=unseen(w.hp,w.seeing)
        if s.improved then open=open*(1-hidden)
        elseif s.invisible then open=open*(1-hidden/math.max(r,1)) end
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
    local hidden=unseen(sp.personal,sp.seeing)
    if s.improved then personal=1-(1-personal)*(1-hidden)
    elseif s.invisible then personal=1-(1-personal)*(1-hidden/math.max(r,1)) end
    local kinds=0
    for kind,part in pairs(M.DISABLES) do if s.covers[kind] then kinds=kinds+part end end
    local free=(1-clamp(kinds,0,1))*(1-share(s.all,top,s.personal))*(1-mr)*(1-clamp(0.05*s.saves,0,0.5))
    if s.improved then free=free*(1-hidden) end
    return {rate=rate,pool=pool,spell=sp.personal*personal+sp.area*area,personal=personal,disable=1-free}
end

-- How harm runs for friend f under threat t with shield s over r rounds: the hit points it has
-- lost by then (temporary hit points go first), the round it dies in (math.huge if it lives
-- through them), and what s blocks. Absorbed hits go first; the rest of the harm runs evenly.
-- A friend with a minimum (targeting.minimum) loses no more than it has above it, and lives.
function M.course(s,f,t,r)
    local maxHp=number(f.maxHp) and f.maxHp>0 and f.maxHp or 1
    local left=number(f.hp) and f.hp>0 and f.hp or maxHp
    local floor=targeting.minimum(f)
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
    local lost=math.max(0,harm-s.hp)
    if floor>0 then lost,death=math.min(lost,math.max(0,left-floor)),math.huge end
    return lost,death,b
end

-- The expected loss of friend f under threat t with shield s over r rounds, on the attack's
-- scale: the share of its hit points it loses, the kill bonus as likely as it dies (not while its
-- minimum holds), and the rounds it is out of the fight, dead or disabled, each worth a round of
-- disable. A protection that keeps a friend alive for longer is worth the rounds it fights in
-- the meantime.
function M.loss(s,f,t,r,killBonus)
    local maxHp=number(f.maxHp) and f.maxHp>0 and f.maxHp or 1
    local left=number(f.hp) and f.hp>0 and f.hp or maxHp
    local harm,death,b=M.course(s,f,t,r)
    local dies=targeting.minimum(f)>0 and 0 or clamp((harm-0.5*left)/(0.5*left),0,1)
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
-- What a buff or debuff role adds to attack data a: to-hit points, damage, the per cent of damage
-- of a's kind, and critical hit points. THAC0 itself set or scaled (opcode 54) counts by a's THAC0,
-- where less is better.
local function edge(role,a,debuff)
    if type(role)~='table' then return 0,0,0,0 end
    local k=type(role.kinds)=='table' and role.kinds or {}
    local hit=amount(role,'thac0')+math.max(0,a.thac0)*amount(role,'thac0Percent')/100
    if not debuff then
        hit=hit+(k.bless and 1 or 0)+(k.aid and 1 or 0)+0.5*(amount(role,'luck')+(k.chant and 1 or 0))
    end
    if number(role.thac0Set) then hit=hit+math.max(0,debuff and role.thac0Set-a.thac0 or a.thac0-role.thac0Set) end
    local by=type(role.damagePercentBy)=='table' and role.damagePercentBy or {}
    local label=weapons.DAMAGE[a.damageType]
    local percent=(number(by[0]) and by[0] or 0)+(label and number(by[M.PERCENT_TYPES[label]]) and by[M.PERCENT_TYPES[label]] or 0)
    return hit,amount(role,'damage'),percent,amount(role,'critical')
end
-- What a buff or debuff role's strength changes of the bonuses to hit and to damage of weapon held
-- (its attack data: the wielder's strength and exceptional strength, and which bonuses the weapon
-- takes), by the game's strength tables (arsenal.might: the installed ones, else the shipped ones):
-- the score it sets, else its own plus the points it adds or takes; exceptional strength likewise
-- (the game caps strength at 25, exceptional strength at 100). A buff's gain, a debuff's loss; a set
-- below what the wielder has is a loss for a buff. None for a weapon that takes neither bonus or a
-- strength not known.
local function might(role,held,debuff,tables)
    if type(role)~='table' or type(held)~='table' or not number(held.str) or not (held.strengthHit or held.strengthDamage) then
        return 0,0
    end
    local sign=debuff and -1 or 1
    local extra=number(held.strExtra) and held.strExtra or 0
    local str=number(role.strengthSet) and role.strengthSet or held.str+sign*amount(role,'strength')
    local ex=number(role.strengthExtraSet) and role.strengthExtraSet or extra+sign*amount(role,'strengthExtra')
    str,ex=clamp(math.floor(str+0.5),0,25),clamp(math.floor(ex+0.5),0,100)
    local hit0,damage0=arsenal.might(tables,clamp(math.floor(held.str+0.5),0,25),clamp(math.floor(extra+0.5),0,100))
    local hit1,damage1=arsenal.might(tables,str,ex)
    local hit=held.strengthHit and hit1-hit0 or 0
    local damage=held.strengthDamage and damage1-damage0 or 0
    return sign*hit,sign*damage
end
-- A swing's expected damage: d on a hit; a critical hit (a roll of 20 less crit, at least 1 in
-- 20) always hits and doubles d where no helmet keeps it off.
local function swing(h,d,crit)
    local q=clamp((1+crit)/20,0.05,1)
    return d*(math.max(h,q)+(q-0.05)*M.critOpen)
end
local function reaches(role) return type(role)=='table' and type(role.who)=='table' and (role.who.target or role.who.area) end
-- What on-hit effects (hits, combat-intent/spells.lua) bring through the hits of weapon held over
-- r rounds, swung apr times a round with thac0 and crit critical hit points, as a share of an
-- enemy: for each living enemy, what one hit's payload does there (combat-intent/harm.lua): its
-- damage on every hit that lands past Mirror Images and Stoneskin skins, a critical hit effect's
-- (F2e) on the critical hits among them where no helmet keeps them off (M.critOpen), either on the
-- first alone for a payload the hit takes off again (once); the strongest disable and the strongest
-- debuff once, as likely as a hit that brings it lands, the debuff against the armour class of the
-- holder's side and none on an enemy that carries it already (harm.carries); the mean over the
-- enemies. What an enemy's spell protections keep out counts nothing.
local function payload(hits,held,apr,thac0,crit,frame,r)
    local list=weapons.payloads(hits,held)
    if #list==0 then return 0 end
    local ac=threat.armour(threat.friends(frame))
    local total,n=0,0
    for _,e in ipairs(type(frame.enemies)=='table' and frame.enemies or {}) do
        if targeting.alive(e) then
            n=n+1
            local maxHp=number(e.maxHp) and e.maxHp>0 and e.maxHp or M.enemyHp
            local hp=number(e.hp) and e.hp>0 and e.hp or maxHp
            local absorbed=(number(e.mirror) and e.mirror>0 and e.mirror or 0)+(number(e.skins) and e.skins>0 and e.skins or 0)
            local chance=threat.hitChance(thac0,number(e.ac) and e.ac or M.enemyAc)
            local landed=math.max(0,apr*chance*r-absorbed)
            local crits=landed*weapons.critical(chance,crit)*M.critOpen
            local dealt,disabled,weakened=0,0,0
            for _,h in ipairs(list) do
                local roles=spells.view(h.strike,targeting.holds(e))
                if type(roles)=='table' and not targeting.protected(e,h.strike) then
                    local floor=targeting.floor(e,roles)
                    local times=h.critical and crits or landed
                    if h.once then times=math.min(1,times) end
                    if reaches(roles.damage) then
                        local _,each=harm.damage(roles.damage,e,0,floor)
                        dealt=dealt+each*times
                    end
                    if reaches(roles.disable) then
                        disabled=math.max(disabled,harm.disable(roles.disable,e,0,floor)*math.min(1,times))
                    end
                    if reaches(roles.debuff) and not harm.carries(e,h.strike,h.source) then
                        weakened=math.max(weakened,harm.debuff(roles.debuff,e,ac)*math.min(1,times))
                    end
                end
            end
            total=total+math.min(dealt,hp)/maxHp+disabled+weakened
        end
    end
    return n>0 and total/n or 0
end
-- The share of an enemy a buff's extra weapon damage takes through friend f over r rounds; only
-- friends with attack data and an enemy within a round's walk fight. held: the attack data f
-- swings with (f.attack when nil); own: what the spell puts on f itself (its debuff role); hits:
-- the on-hit effects it gives f (payload); tables: the game's strength tables (might). A haste f
-- holds already (its guard's roles) is not hastened again; an improved one over a normal one adds
-- what doubling its attacks before that brings.
function M.offense(buff,f,frame,r,held,own,hits,tables)
    held=held or f.attack
    if type(buff)~='table' or type(held)~='table' then return 0 end
    local ac,hp,n=enemies(frame)
    if n==0 then return 0 end
    local close=false
    for _,e in ipairs(frame.enemies) do
        if targeting.alive(e) and targeting.distance(e,f)<=threat.reach+threat.stride then close=true;break end
    end
    if not close then return 0 end
    local a=threat.attack({attack=held})
    local k=type(buff.kinds)=='table' and buff.kinds or {}
    local apr=a.apr+M.attacks(amount(buff,'attacks'))
    local guard=type(f.guard)=='table' and type(f.guard.roles)=='table' and f.guard.roles.buff
    local had=type(guard)=='table' and type(guard.kinds)=='table' and guard.kinds or {}
    if k.haste and not had.improvedHaste then
        if k.improvedHaste then apr=apr+(had.haste and math.max(0,a.apr-2) or a.apr)
        elseif not had.haste then apr=apr+1 end
    end
    local hit,damage,percent,crit=edge(buff,a)
    local stronger,harder=might(buff,held,false,tables)
    hit,damage=hit+stronger,damage+harder
    local lost,less,fewer,blunt=edge(own,a,true)
    local weaker,softer=might(own,held,true,tables)
    lost,less=lost+weaker,less+softer
    local d=math.max(0,a.damage+damage-less+a.damage*(percent-fewer)/100)
    local before=a.apr*swing(threat.hitChance(a.thac0,ac),a.damage,0)
    local after=apr*swing(threat.hitChance(a.thac0-hit+lost,ac),d,crit-blunt)
    return math.max(0,after-before)*r/hp+payload(hits,held,apr,a.thac0-hit+lost,crit-blunt,frame,r)
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
-- Whether a role reaches the caster and no one else.
local function ownOnly(who)
    for k,v in pairs(who) do if v and k~='self' then return false end end
    return who.self==true
end
-- Heals and removals that ride along on the user alone: Barbarian Rage, Potion of Haste and
-- Potion of Free Action take earlier copies or slowing effects off it, Enrage heals it a little.
local OWN={heal=true,removal=true}
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
    -- Summons, raising, healing and removal are decisions of their own (combat-intent/summons.lua,
    -- care.lua, removal.lua), unless the heal or removal reaches the caster alone.
    for _,name in ipairs({'summon','heal','raise','removal'}) do
        local r=spell.roles[name]
        if type(r)=='table' and type(r.who)=='table' and next(r.who) and not (OWN[name] and ownOnly(r.who)) then
            return nil,'role-'..name
        end
    end
    -- own: what the spell puts on the caster itself besides (Whirlwind Attack's penalties); hits:
    -- its on-hit effects (combat-intent/spells.lua).
    local d=spell.roles.debuff
    local own=type(d)=='table' and type(d.who)=='table' and d.who.self and d or nil
    return {protection=forFriends(p) and p or nil,buff=forFriends(b) and b or nil,own=own,
        hits=type(spell.hits)=='table' and spell.hits or nil}
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
-- The on-hit effects of a spell (hits) that friend f gets from a cast aimed at aim: those on the
-- caster only for the caster, those on the creature it is cast at only for that one, the rest
-- (areas) for every friend the cast reaches.
local function hitsFor(hits,f,caster,aim)
    local out={}
    for _,h in ipairs(type(hits)=='table' and hits or {}) do
        if (h.who=='self' and f==caster) or (h.who=='target' and aim.friend==f) or (h.who~='self' and h.who~='target') then
            out[#out+1]=h
        end
    end
    return out
end

-- Who the spell reaches, aimed as it is cast: the caster for a spell on itself, the friends
-- within the area around the caster or a point, an ally an exception names; not a friend whose
-- spell protections keep the spell out (lab batch H: an ally's globe), though the caster's own
-- let its own spell through (targeting.protected).
local function receivers(input,row,spell,aim)
    local frame=input.frame
    local out={}
    local function add(f)
        if type(f.protections)~='table' or not targeting.protected(f,spell,f==frame.self) then out[#out+1]=f end
    end
    local area=spell.area
    if aim.point and area and number(area.radius) then
        for _,f in ipairs(threat.friends(frame)) do
            if targeting.distance(aim.point,f)<=area.radius then add(f) end
        end
        return out
    end
    if aim.friend then add(aim.friend) end
    return out
end
-- Where a defence can be cast: on the caster itself (also an area around it); at the caster's
-- spot or an ally's for a spell aimed at a point; at an ally for an agreed exception. Only at
-- allies the caster sees (targeting.seen).
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
            if f~=caster and targeting.seen(caster,f) and targeting.distance(caster,f)<=range then
                out[#out+1]={point={x=f.x,y=f.y}}
            end
        end
    elseif spell.target=='creature' then
        out[1]={self=true,friend=caster}
        local allowed=type(input.mind.allySpells)=='table' and input.mind.allySpells[row.resref]
        if allowed then
            for _,f in ipairs(threat.friends(frame)) do
                if f~=caster and targeting.seen(caster,f) and targeting.distance(caster,f)<=range then
                    out[#out+1]={friend=f}
                end
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
    if not t or not number(input.mind.acute) or quiet(input) then return false end
    local left=number(caster.hp) and caster.hp>0 and caster.hp or 1
    return (M.course(M.held(caster),caster,t,1))>=input.mind.acute*left
end
-- The chance the caster finishes a cast of the given seconds: each hit or aimed spell that gets
-- through what protects it now can break the cast; absorbed hits do not.
function M.through(input,t,cast)
    if not t or cast<=0 then return 1 end
    local stop=quiet(input)
    if stop and cast<=stop then return 1 end
    local b=M.blocks(M.held(input.frame.self),t,1)
    local part=cast/M.ROUND
    local hits=math.max(0,t.weapon.hits*(1-b.rate)*part-b.pool)
    return math.exp(-hits-t.spell.casters*threat.personal*(1-b.personal)*part)
end

-- What a defence weakens of the enemies its area reaches as cast at aim (F2b: Prayer, Recitation
-- and Chant curse the enemies around the priest while they bless its side): each enemy's debuff
-- (combat-intent/harm.lua) against the armour class ac of the caster's side, on the attack's
-- scale; none on an enemy its spell protections keep the spell off or that carries the spell's
-- effects already.
local function weakens(input,row,spell,aim,ac)
    local area=spell.area
    if not aim.point or type(area)~='table' or not number(area.radius) then return 0 end
    local worth=0
    for _,e in ipairs(type(input.frame.enemies)=='table' and input.frame.enemies or {}) do
        if type(e)=='table' and targeting.alive(e) and targeting.distance(aim.point,e)<=area.radius and
            not targeting.protected(e,spell) and not harm.carries(e,spell,row.resref) then
            local roles=spells.view(spell,targeting.holds(e))
            local d=type(roles)=='table' and roles.debuff
            if type(d)=='table' and type(d.who)=='table' and d.who.area and
                (type(d.filters)~='table' or d.filters.enemies or d.filters.all) then
                worth=worth+harm.debuff(d,e,ac)
            end
        end
    end
    return worth
end

-- Every defence option the caster has: {resref, kind='defence', mode, worth, cost, score, hits
-- (the friends it reaches), slack=0, and self, point or target as the cast is aimed; use=true for
-- an item it drinks}. rejected (optional) counts why ready defensive spells and carried items gave
-- none. A friend's guard false means it could not be read. A defence that follows the last one
-- within mind.redefend seconds waits, as SCS's does, unless the caster is in acute danger. An item
-- (the protection and buff potions SCS's fighters drink) works on the caster itself while it has
-- uses left, costs as a first-level spell and is not interrupted (as care.lua's potions). What a
-- spell's area weakens of enemies (weakens) adds to what it gives its side, which caution weighs.
-- A defence that leaves the caster invisible as a backstab needs (plain invisibility, F2d) adds what
-- the backstab after it gains (input.hideOpening, combat-intent/choice.lua), less the part of a
-- round its casting takes (weapons.paced); such an option carries hides and that opening. A buff
-- counts over the rest of the fight as long as it lasts (rest, the seconds it reckoned with), a
-- protection over the horizon, each from the end of the caster's own Time Stop or of the calm on
-- (see the top); input.tables holds the game's strength tables (might). boosts: what
-- the option gives adds to attacks (a buff potion, which a creature drinks before its attack:
-- combat-intent/choice.lua).
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
    local rest=threat.rest(frame,number(mind.fightCap) and mind.fightCap or 60)
    local tables=type(input.tables)=='table' and input.tables or nil
    local killBonus=number(mind.killBonus) and mind.killBonus or 0
    local stop=quiet(input) or 0
    -- Foes out of play are not where an area could weaken them.
    local away=number(input.calm)
    local held={}
    local function heldOf(f) held[f.id]=held[f.id] or M.held(f);return held[f.id] end
    local caster=frame.self
    local ct=pictures[caster.id]
    -- The weapon the caster swings when its profile fights with it.
    local wielded=mind.ownWeapon==true and threat.wielded(caster) or nil
    local caution=number(mind.caution) and mind.caution or 1
    local ac=threat.armour(threat.friends(frame))
    -- The option of one ready spell (row) or carried item (row.item), or false and why it gives
    -- none: no defence at all is false and nil.
    local function consider(row,spell)
        local gives,why=M.defence(spell)
        if not gives then
            if why~='no-defence' and why~='attack' and why~='unclassified' then return false,why end
            return false
        end
        if waiting then return false,'redefend' end
        local shield=M.shield(gives)
        local length=math.max(seconds(gives.protection),seconds(gives.buff))
        local rounds=math.max(0,math.min(horizon,length-stop))/M.ROUND
        local fights=math.max(0,math.min(rest,seconds(gives.buff)-stop))/M.ROUND
        local cast=(number(spell.speed) and spell.speed or 0)*M.speedSeconds
        local hide=input.hideOpening
        local opening=type(hide)=='table' and number(hide.worth) and hide.worth>0 and shield.invisible and
            not shield.improved and hide.worth*weapons.paced(row.item and 0 or cast) or 0
        local best,unknown
        local list=row.item and {{self=true,friend=caster,point=spell.area and {x=caster.x,y=caster.y} or nil}}
            or aims(input,row,spell)
        for _,aim in ipairs(list) do
            local worth,hits,open,boost=0,{},0,0
            for _,f in ipairs(receivers(input,row,spell,aim)) do
                if f==caster then open=opening end
                -- What protects a friend whose effects could not be read is unknown: it gets
                -- nothing rather than a second copy.
                if f.guard==false then unknown=true
                elseif not guarded(f,row.resref) then
                    local t=pictures[f.id]
                    local gain,more=0,0
                    if t and rounds>0 then
                        local now=heldOf(f)
                        gain=M.loss(now,f,t,rounds,killBonus)-M.loss(M.union(now,shield),f,t,rounds,killBonus)
                    end
                    local own=hitsFor(gives.hits,f,caster,aim)
                    if f~=caster then more=M.offense(gives.buff,f,frame,fights,nil,nil,own,tables)
                    elseif wielded then more=M.offense(gives.buff,f,frame,fights,wielded,gives.own,own,tables) end
                    gain=gain+more
                    if gain>0 then worth=worth+gain;hits[#hits+1]=f.id;boost=boost+more end
                end
            end
            if open>0 then
                local listed=false
                for _,id in ipairs(hits) do if id==caster.id then listed=true end end
                if not listed then table.insert(hits,1,caster.id) end
            end
            -- Caution weighs what it gives the side; a profile without any (labs) still sees it.
            local weak=(row.item or away) and 0 or weakens(input,row,spell,aim,ac)
            local total=worth*caution+weak+open
            if worth+weak+open>0 and (not best or total>best.total or (total==best.total and worth>best.worth)) then
                best={aim=aim,total=total,worth=worth,hits=hits,open=open,boost=boost}
            end
        end
        if not best then return false,unknown and 'unknown-guard' or 'no-worth' end
        -- Casting time: harm while casting can interrupt a cast (not a drink); long casts also cost.
        local through=row.item and 1 or M.through(input,ct,cast)
        local level=row.item and M.itemLevel or slots(input)*(number(row.level) and row.level or
            number(spell.level) and spell.level or 1)
        local cost=(number(mind.economy) and mind.economy or 1)*M.costPerLevel*level+
            (number(mind.castCost) and mind.castCost or 0)*cast
        local worth=best.total*through
        local option={resref=row.resref,kind='defence',worth=worth,cost=cost,score=worth-cost,
            hits=best.hits,slack=0,speed=number(spell.speed) and spell.speed or 0,release=spell.release or nil,
            use=row.item or nil,hides=best.open>0 or nil,opening=best.open>0 and best.open or nil,
            rest=gives.buff and rest or nil,boosts=best.boost>0 or nil}
        local aim=best.aim
        if aim.self then option.self=true;option.mode='self'
        elseif aim.friend then option.target=aim.friend.id;option.mode='ally'
        else option.point={x=math.floor(aim.point.x+0.5),y=math.floor(aim.point.y+0.5)};option.mode='point' end
        return option
    end
    for _,row in ipairs(type(input.spells)=='table' and input.spells or {}) do
        if type(row)=='table' and number(row.ready) and row.ready>0 and row.usable then
            local option,why=consider(row,row.spell)
            if option then out[#out+1]=option elseif why then reject(why) end
        end
    end
    -- Items the caster carries: the first ability of each that defends, while uses are left.
    for _,it in ipairs(type(input.items)=='table' and input.items or {}) do
        if type(it)=='table' and type(it.resref)=='string' then
            for _,a in ipairs(type(it.abilities)=='table' and it.abilities or {}) do
                local effect=type(a)=='table' and a.effect
                if type(effect)=='table' and effect.target~='point' and (not number(a.uses) or a.uses>0) and M.defence(effect) then
                    local option,why=consider({resref=it.resref,item=true},effect)
                    if option then out[#out+1]=option elseif why then reject(why) end
                    break
                end
            end
        end
    end
    return out
end
return M
