-- What an attack's damage, disable or debuff does to one creature, on the attack's scale (shares
-- of a creature taken out of the fight), as plain numbers. The engine's own attacks weigh their enemies
-- with it (combat-intent/choice.lua, which adds its focus and what it remembers of misses), and
-- danger zones weigh the caster with it (combat-intent/zones.lua): what a cloud does to a creature
-- counts as much as the same spell on an enemy. Nothing here touches the engine or raises on odd
-- data.
local targeting=require('combat-intent.targeting')
local ids=require('combat-intent.ids')
local threat=require('combat-intent.threat')
local weapons=require('combat-intent.weapons')
local arsenal=require('combat-intent.arsenal')
local M={}
-- A disable lasting this long counts in full (three rounds).
M.fullSeconds=18
-- What each kind of disable is worth on a creature in full health, for the full time. Death,
-- petrification and imprisonment take it out for good.
M.DISABLE={hold=1,stun=1,sleep=0.8,charm=1.2,confusion=0.8,panic=0.7,berserk=0.4,feeblemind=1,
    silence=0.7,nocast=0.7,entangle=0.5,web=0.6,root=0.3,polymorph=1,pause=0.8,maze=1.2,
    turnUndead=1,petrify=1,imprison=1,death=1}
M.FOR_GOOD={petrify=true,imprison=true,death=true}
-- Disables that put their creature out of the caster's side's reach while they hold: our side
-- never harms a foe it charmed (Christopher, 2026-10-29: harming it breaks the charm by the rules
-- text), and nobody reaches one in a maze. On the last foe in play they only put the fight off
-- (lab batch J run 3: the erinyes charmed the party's last member again each time its charm
-- ended, until the time ran out), so they count for nothing there.
M.UNTOUCHED={charm=true,maze=true}
-- One charmed already, which the other side charmed (combat-intent/targeting.lua, M.charmed), is
-- freed, not charmed over (combat-intent/removal.lua): the charm of a caster of the evil side sets
-- its creature's allegiance to the good side for after the charm (IESDP, opcode 5, the hostile
-- types; lab batch J, run 3: the group's fighter-thief and kensai, under a Dire Charm the party's
-- mage began before the group charmed it, stood with the party once it ended), so a member charmed
-- back would turn on its group for good.
-- Disables that matter only against casters.
M.CASTERS_ONLY={feeblemind=true,silence=true,nocast=true}
-- Damage types to the resistance a creature's details carry (adapters/eeex/sense.lua reads
-- SCS's stats).
M.RESIST={fire='fire',cold='cold',electricity='electricity',acid='acid',magic='magic',
    magicfire='magicfire',magiccold='magiccold',slashing='slashing',crushing='crushing',
    piercing='piercing',missile='missile',poison='poison'}

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end

-- The share of a damage type that gets through e's resistance.
function M.resisted(e,label)
    local r=type(e.resist)=='table' and e.resist[M.RESIST[label] or '']
    if not number(r) then return 1 end
    return math.max(0,1-r/100)
end

-- How long a condition holds on e when e gets a save every bf.every seconds to break free
-- (breakFree, combat-intent/spells.lua: Spell Revisions' Greater Command): the first stretch for
-- sure, each later one while every save so far failed, up to the condition's duration.
function M.brokenFree(duration,bf,e)
    if not number(duration) or duration<=0 then return 0 end
    local every=type(bf)=='table' and number(bf.every) and bf.every>0 and bf.every or duration
    local s=type(bf)=='table' and targeting.saveChance({save=bf.save,saveBonus=bf.saveBonus},e) or 0
    local held,stay,t,steps=0,1,0,0
    while t<duration and steps<100 do
        local span=math.min(every,duration-t)
        held=held+span*stay
        t=t+span;steps=steps+1
        stay=stay*(1-s)
    end
    return held
end

-- Damage by the dice (2026-10-28; before, a kill counted in full once the average reached the hit
-- points left, so a creature about one explosion's average from death saw no worth in leaving a
-- cloud). A spread is the chance of each whole number of hit points taken (index: hit points + 1),
-- cut off at a top: its last entry holds the chance of the top or more. A fraction goes to the two
-- whole numbers around it by how near each is, so a spread's mean is what the averages give.
local function zeros(n) local t={} for i=1,n do t[i]=0 end return t end
-- A roll whose dice can reach more hit points than this counts as its average.
M.manyDice=4000
local DICE={}
-- The chances of each total of n dice with s sides (index total + 1), nil for too many; kept.
local function dice(n,s)
    if n<=0 or s<=0 then return {1} end
    if n*s>M.manyDice then return nil end
    local key=n..':'..s
    if DICE[key] then return DICE[key] end
    local p={1}
    for _=1,n do
        local q,window={},0
        for i=1,#p+s do
            window=window+(p[i-1] or 0)-(p[i-1-s] or 0)
            q[i]=window>0 and window/s or 0
        end
        p=q
    end
    DICE[key]=p
    return p
end
-- Adds the chance pr of x hit points to spread t (top: its last index - 1).
local function put(t,x,pr,top)
    if x<=0 then t[1]=t[1]+pr;return end
    local lo=math.floor(x)
    if lo>=top then t[top+1]=t[top+1]+pr;return end
    local up=x-lo
    t[lo+1]=t[lo+1]+pr*(1-up)
    if up>0 then t[lo+2]=t[lo+2]+pr*up end
end
-- Spreads a and b added up, cut off at top.
local function sum(a,b,top)
    local size=math.min(#a+#b-1,top+1)
    local out=zeros(size)
    for i=1,#a do
        local pa=a[i]
        if pa>0 then
            for j=1,#b do
                local k=i+j-1
                if k>size then k=size end
                out[k]=out[k]+pa*b[j]
            end
        end
    end
    return out
end
-- Spread a as likely as c, else nothing.
local function maybe(a,c)
    if c>=1 then return a end
    local out={}
    for i=1,#a do out[i]=a[i]*math.max(c,0) end
    out[1]=out[1]+1-math.max(c,0)
    return out
end
-- Spread a cut off at top.
local function cut(a,top)
    if #a<=top+1 then return a end
    local out={}
    for i=1,top do out[i]=a[i] end
    local rest=0
    for i=top+1,#a do rest=rest+a[i] end
    out[top+1]=rest
    return out
end
-- k spreads a added up, cut off at top (stops once all of it is at the top).
local function times(a,k,top)
    local out={1}
    if k<=8 then
        for _=1,k do
            out=sum(out,a,top)
            if #out==top+1 and out[top+1]>=1-1e-12 then break end
        end
        return out
    end
    local base=a
    while k>0 do
        if k%2==1 then out=sum(out,base,top) end
        k=math.floor(k/2)
        if k>0 then base=sum(base,base,top) end
    end
    return out
end
-- What one roll does through resistance factor f, cut off at top: its flat part and dice, as
-- likely as it lands, as many times as it lands (a fraction of a time as likely as that).
local function rolled(roll,f,top)
    local n=number(roll.dice) and roll.dice>0 and roll.dice or 0
    local s=number(roll.sides) and roll.sides>0 and roll.sides or 0
    local flat=number(roll.flat) and roll.flat>0 and roll.flat or 0
    local base=dice(n,s)
    if base==nil then flat,base=flat+n*(s+1)/2,{1} end
    local last=math.min(math.ceil((flat+#base-1)*f),top)
    local t=zeros(last+1)
    for i=1,#base do
        if base[i]>0 then put(t,(flat+i-1)*f,base[i],last) end
    end
    t=maybe(t,number(roll.p) and roll.p or 1)
    local k=number(roll.times) and roll.times>0 and roll.times or 1
    local whole=math.floor(k+1e-9)
    local out=times(t,whole,top)
    if k-whole>1e-9 then out=sum(out,maybe(t,k-whole),top) end
    return out
end

-- The spread of the hit points one application of damage role takes from e, cut off at e's hit
-- points; nil when none gets through. Its rolls (combat-intent/spells.lua) through e's resistances,
-- or its averages by type where it carries none, and the share of e's maximum it takes; then the
-- saving throw (half, or none of it) and magic resistance.
function M.spread(role,e)
    local hp,maxHp=e.hp,e.maxHp
    if type(role)~='table' or not number(hp) or not number(maxHp) or maxHp<=0 or hp<=0 then return nil end
    local top=math.ceil(hp-1e-9)
    local half=role.saveForHalf==true
    local reach=half and 2*top+1 or top
    local d,any={1},false
    local rolls=type(role.rolls)=='table' and #role.rolls>0 and role.rolls or nil
    if rolls==nil then
        rolls={}
        local labels={}
        for label,v in pairs(type(role.types)=='table' and role.types or {}) do
            if number(v) and v>0 then labels[#labels+1]=label end
        end
        table.sort(labels)
        for _,label in ipairs(labels) do rolls[#rolls+1]={label=label,flat=role.types[label]} end
    end
    for _,r in ipairs(rolls) do
        local f=type(r)=='table' and M.resisted(e,r.label) or 0
        if f>0 then d=sum(d,rolled(r,f,reach),reach);any=true end
    end
    if number(role.percent) and role.percent>0 then
        d=sum(d,rolled({flat=maxHp*role.percent/100},1,reach),reach);any=true
    end
    if not any or #d==1 then return nil end
    local save=targeting.saveChance(role,e)
    if half then
        local out=zeros(math.min(#d,top+1))
        for i=1,#d do
            local pr=d[i]
            if pr>0 then
                put(out,i-1,pr*(1-save),#out-1)
                if save>0 then put(out,(i-1)/2,pr*save,#out-1) end
            end
        end
        d=out
    else d=maybe(d,1-save) end
    return maybe(d,targeting.landing(role,e))
end

-- The worth and the hit points expected to be taken of the spreads in parts ({spread, n}: n of
-- them, a fraction of one as likely as that) landing on e together: the share of e's maximum they
-- take, no more than e has left above floor, and the kill bonus as likely as they take all of
-- that. floor: the hit points e keeps at least (its minimum, targeting.floor; one for a strike that
-- keeps its target alive, as Harm does); no kill while one holds (lab batch H9: a priest stayed 39
-- seconds in an Incendiary Cloud to finish a mage whose minimum kept it at one hit point).
function M.outcome(parts,e,killBonus,floor)
    local hp,maxHp=e.hp,e.maxHp
    if not number(hp) or not number(maxHp) or maxHp<=0 or hp<=0 then return 0,0 end
    floor=number(floor) and floor>0 and floor or 0
    local left=hp-floor
    if left<=0 then return 0,0 end
    local cap=math.ceil(left-1e-9)
    local most,mean=0,0
    for _,x in ipairs(parts) do
        local s=x.spread
        most=most+x.n*(#s-1)
        for i=2,#s do mean=mean+x.n*(i-1)*s[i] end
    end
    -- Short of what e has left even at most: the mean, and no kill.
    if most<cap then return mean/maxHp,mean end
    local total={1}
    for _,x in ipairs(parts) do
        local s=cut(x.spread,cap)
        local whole=math.floor(x.n+1e-9)
        local some=times(s,whole,cap)
        local frac=x.n-whole
        if frac>1e-9 then
            local more=sum(some,s,cap)
            local mixed=zeros(math.max(#some,#more))
            for i=1,#some do mixed[i]=mixed[i]+some[i]*(1-frac) end
            for i=1,#more do mixed[i]=mixed[i]+more[i]*frac end
            some=mixed
        end
        total=sum(total,some,cap)
    end
    local expected,kill=0,0
    for i=2,#total do
        if i==cap+1 then kill=total[i];expected=expected+left*total[i]
        else expected=expected+(i-1)*total[i] end
    end
    if floor>0 then kill=0 end
    return expected/maxHp+(number(killBonus) and killBonus or 0)*kill,expected
end

-- The worth of damage role landing n times on e (once by default: a cast; a cloud's explosions)
-- and the hit points it is expected to take (M.outcome).
function M.damage(role,e,killBonus,floor,n)
    local s=M.spread(role,e)
    if s==nil then return 0,0 end
    return M.outcome({{spread=s,n=number(n) and n>0 and n or 1}},e,killBonus,floor)
end

-- Whether e's level lies within the role's levels (any level when e's is unknown).
function M.within(role,e)
    local level=type(e)=='table' and e.level
    return not (number(level) and ((number(role.maxLevel) and level>role.maxLevel) or
        (number(role.minLevel) and level<role.minLevel)))
end
-- The chance a role lands on e and holds: magic resistance, the saving throw and the effect's own
-- chance.
function M.chance(role,e)
    return targeting.landing(role,e)*(1-targeting.saveChance(role,e))*clamp(number(role.chance) and role.chance or 1,0,1)
end
-- How long a role holds on e, as a share of fullSeconds: its duration, or what e keeps of it where
-- it breaks free; all of it when it lasts, half when its duration is unknown.
local function length(role,e)
    if role.duration=='permanent' then return 1 end
    if number(role.duration) and role.duration>0 then
        local span=role.duration
        if type(role.breakFree)=='table' then span=M.brokenFree(span,role.breakFree,e) end
        return clamp(span/M.fullSeconds,0,1)
    end
    return 0.5
end

-- The worth of a disable role on e: what its strongest kind is worth for as long as it holds
-- (taking a nearly dead creature out is worth less than taking out a healthy one; taking one out
-- for good is worth what killing it is), times the chance it lands: magic resistance, the saving
-- throw and the effect's own chance. Nothing on a creature already disabled, outside the role's
-- levels or at or above its hit point limit. While a minimum holds on e (floor above 0, as for
-- M.damage), only a death that slays (role.slays, combat-intent/spells.lua) kills it. alone: e is
-- the last foe in play, where the disables of M.UNTOUCHED count for nothing.
function M.disable(role,e,killBonus,floor,alone)
    if targeting.disabled(e) or not M.within(role,e) then return 0 end
    -- A power word works by the hit points e has now: in a Time Stop, not counting what lands
    -- when time resumes (hpNow).
    local now=number(e.hpNow) and e.hpNow or e.hp
    if number(role.belowHp) and number(now) and now>=role.belowHp then return 0 end
    local factor,forGood=0,false
    for label in pairs(type(role.kinds)=='table' and role.kinds or {}) do
        local f=M.DISABLE[label] or 0
        if M.CASTERS_ONLY[label] and not ids.caster(e) then f=f*0.2 end
        if label=='turnUndead' and not (type(e.ids)=='table' and e.ids.general==4) then f=0 end
        if label=='sleep' and role.wakesOnDamage then f=f*0.6 end
        if label=='death' and number(floor) and floor>0 and not role.slays then f=0 end
        if alone and M.UNTOUCHED[label] then f=0 end
        if label=='charm' and targeting.charmed(e) then f=0 end
        if f>factor then factor,forGood=f,M.FOR_GOOD[label]==true end
    end
    if factor<=0 then return 0 end
    local health=targeting.health(e)
    local bonus=number(killBonus) and killBonus or 0
    local worth=forGood and factor*(health+bonus) or factor*length(role,e)*(0.5+0.5*health)
    return worth*M.chance(role,e)
end

-- Weakening (F2b; IESDP): what a debuff takes from a creature's own fight while it holds, as a
-- share of the harm it deals as combat-intent/threat.lua counts it: its weapon's hits a round
-- (attacks, the chance to hit the armour class it meets, the damage of a hit) and its spells (how
-- much of its class casts, times its level). Slow halves all a creature does: it acts every second
-- tick, so it makes half its attacks and casts in twice the time (ie-duration.md). On EE blindness
-- costs 4 to hit, and two blindnesses no more. Luck counts on attack rolls point for point, a
-- negative chant's too, and fatigue above fatigueFree costs a point of luck each (FATIGMOD.2DA, as
-- for a rested creature). Casting failure counts by kind of spell (wizard, priest, innate), and
-- deafness fails half of wizard and priest spells besides. A lower casting level weakens a
-- creature's spells by the levels it takes, and drained levels weaken its weapon and its spells by
-- theirs. A creature already slowed or blind gets nothing more from another slow or blindness.
-- Lower strength counts through the game's strength tables (arsenal.might: the installed ones, else
-- the shipped ones) on a weapon that takes strength's bonuses. Lower dexterity and constitution do
-- not count yet.
M.blindHit=4
M.blindArmor=4
M.deafFailure=50
M.fatigueFree=6
-- The damage types opcode 332 lowers (its parameter 2) for each kind of weapon damage; 0 lowers all.
local PERCENT_TYPES={slashing=7,piercing=8,crushing=9,missile=10}
local function amount(role,label)
    local a=type(role)=='table' and role.amounts
    local v=type(a)=='table' and a[label]
    return number(v) and v or 0
end
-- What a debuff role's lower strength takes from the bonuses to hit and to damage of weapon held
-- (the wielder's strength and exceptional strength, and which bonuses the weapon takes), by
-- arsenal.might: the score it sets, else its own less the points it takes; exceptional strength
-- likewise. None when the score does not lower them, for a weapon that takes neither bonus, or for
-- a strength not known.
local function might(role,held,tables)
    if type(held)~='table' or not number(held.str) or not (held.strengthHit or held.strengthDamage) then
        return 0,0
    end
    local extra=number(held.strExtra) and held.strExtra or 0
    local str=number(role.strengthSet) and role.strengthSet or held.str-amount(role,'strength')
    local ex=number(role.strengthExtraSet) and role.strengthExtraSet or extra-amount(role,'strengthExtra')
    local low=type(tables)=='table' and type(tables.strmod)=='table' and tables.strmod[0]~=nil and 0 or 1
    str,ex=clamp(math.floor(str+0.5),low,25),clamp(math.floor(ex+0.5),0,100)
    local hit0,damage0=arsenal.might(tables,clamp(math.floor(held.str+0.5),low,25),clamp(math.floor(extra+0.5),0,100))
    local hit1,damage1=arsenal.might(tables,str,ex)
    return held.strengthHit and math.max(0,hit0-hit1) or 0,held.strengthDamage and math.max(0,damage0-damage1) or 0
end
-- The share of e's spells that fail under role: by the kinds of spell its classes cast, half each
-- for one that casts both; one of no casting class casts innate abilities.
local function failing(role,e)
    local by=type(role.miscastBy)=='table' and role.miscastBy or {}
    local deaf=type(role.kinds)=='table' and role.kinds.deaf and M.deafFailure or 0
    local total,n=0,0
    for _,kind in ipairs({'arcane','divine'}) do
        if ids[kind](e) then
            total,n=total+math.min(100,(number(by[kind]) and by[kind] or 0)+deaf),n+1
        end
    end
    if n==0 then return clamp((number(by.innate) and by.innate or 0)/100,0,1) end
    return total/n/100
end
-- What role takes from e's fight while it holds, a share from 0 to 1. ac: the armour class e's
-- weapon meets (threat.hitChance's default when nil); tables: the game's strength tables. The
-- caster itself carries the weapon in its hand (weapon) rather than attack data.
function M.weaken(role,e,ac,tables)
    if type(role)~='table' or type(e)~='table' then return 0 end
    local k=type(role.kinds)=='table' and role.kinds or {}
    local held=e.attack
    if held==nil and type(e.weapon)=='table' then held=threat.wielded(e) end
    local a=threat.attack({attack=held})
    local level=number(e.level) and e.level>0 and e.level or 1
    local armed=held~=false
    local weapon=armed and a.apr*threat.hitChance(a.thac0,ac)*a.damage or 0
    local spell=threat.casting(e)*threat.spellPerLevel*level
    if weapon+spell<=0 then return 0 end
    local slow=(k.slow and not targeting.has(e.state,targeting.STATE.slowed)) and 0.5 or 1
    local kept=math.max(0,level-amount(role,'drain'))/level
    local strHit,strDamage=might(role,held,tables)
    local worse=amount(role,'thac0')+strHit+amount(role,'luck')+math.max(0,amount(role,'fatigue')-M.fatigueFree)+
        math.max(0,a.thac0)*amount(role,'thac0Percent')/100
    if number(role.thac0Set) then worse=worse+math.max(0,role.thac0Set-a.thac0) end
    if k.blind and not targeting.has(e.state,targeting.STATE.blind) then worse=worse+M.blindHit end
    local by=type(role.damagePercentBy)=='table' and role.damagePercentBy or {}
    local label=weapons.DAMAGE[a.damageType]
    local typed=label and by[PERCENT_TYPES[label]]
    local percent=(number(by[0]) and by[0] or 0)+(number(typed) and typed or 0)
    local apr=math.max(0,a.apr-threat.attacks(amount(role,'attacks')))*slow
    -- Bad luck for base weapon damage lowers the weapon's own dice (threat.luckGain: 0 unknown).
    local unlucky=threat.luckGain(a.rolls,-amount(role,'damageLuck'))
    local damage=math.max(0,a.damage-amount(role,'damage')-strDamage+unlucky)*math.max(0,1-percent/100)
    local after=armed and apr*threat.hitChance(a.thac0+worse,ac)*damage*kept or 0
    local power=math.max(0,level-amount(role,'castingLevel'))/level
    local cast=spell*slow*kept*power*(1-failing(role,e))
    return clamp(1-(after+cast)/(weapon+spell),0,1)
end

-- Whether e carries a spell's effects already: one of its active effects (e.wards,
-- adapters/eeex/sense.lua) comes from the spell or from what it delivers (spell.sources, the
-- spell's own resref among them; resref when the spell names none), or the spell is among those
-- that land on e when time resumes (e.carried, combat-intent/choice.lua's frozen). Without wards
-- read, only those.
function M.carries(e,spell,resref)
    if type(e)~='table' or (type(e.wards)~='table' and type(e.carried)~='table') then return false end
    local from={}
    for res in pairs(type(spell)=='table' and type(spell.sources)=='table' and spell.sources or {}) do
        if type(res)=='string' and res~='' then from[res:upper()]=true end
    end
    if type(resref)=='string' and resref~='' then from[resref:upper()]=true end
    for res in pairs(type(e.carried)=='table' and e.carried or {}) do
        if type(res)=='string' and from[res:upper()] then return true end
    end
    for _,w in ipairs(type(e.wards)=='table' and e.wards or {}) do
        if type(w)=='table' and type(w.source)=='string' and from[w.source:upper()] then return true end
    end
    return false
end

-- Teleport Field (opcode 222; Christopher, 2026-11-03: a tactical spell, "auch AI muss sich
-- positionieren, genau wie Spieler"): each explosion sends a foe off in a random direction, up to the
-- role's teleportRange (IESDP; measured as a projectile's radius, as the engine measures distances). One
-- that fights someone in melee walks back the part of the jump beyond its weapon's reach (threat.reach)
-- and loses that walk from its fight: on average (range-reach)^2/(2*range) world units for a jump's
-- length even over the range, which IESDP leaves open (the lab's Teleport Field probe checks it).
function M.displaced(role,e)
    local a=type(role)=='table' and role.amounts
    local range=type(a)=='table' and number(a.teleportRange) and a.teleportRange or 0
    if type(e)~='table' or range<=threat.reach then return 0 end
    return (range-threat.reach)^2/(2*range)/weapons.speed(e)
end
-- The worth of n explosions of a Teleport Field on e when e fights someone in melee: the seconds it
-- loses walking back as each lands (M.chance), as a disable that long counts (M.debuff: up to
-- fullSeconds). Nothing on a creature already disabled or outside the role's levels.
function M.teleport(role,e,n)
    if type(role)~='table' or type(e)~='table' or not number(n) or n<=0 or targeting.disabled(e) or
        not M.within(role,e) then return 0 end
    local lost=math.min(M.fullSeconds,n*M.displaced(role,e)*M.chance(role,e))
    return lost/M.fullSeconds*(0.5+0.5*targeting.health(e))
end

-- The worth of a debuff role on e: the share of e's fight it takes (M.weaken, with ac and tables as
-- there) for as long as it holds, as a disable counts its kind (a hold that takes all of a healthy
-- creature's fight for the full time is worth 1), times the chance it lands. Nothing on a creature
-- already disabled or outside the role's levels.
function M.debuff(role,e,ac,tables)
    if type(role)~='table' or type(e)~='table' or targeting.disabled(e) or not M.within(role,e) then return 0 end
    local share=M.weaken(role,e,ac,tables)
    if share<=0 then return 0 end
    return share*length(role,e)*(0.5+0.5*targeting.health(e))*M.chance(role,e)
end

-- e as it stands under role's lower defences, for what other attacks gain from them: a copy with
-- its saving throws worse by the role's points per save, its magic resistance and resistances
-- lower and its armour class worse by the role's points and blindness's 4 (once, on EE); nil when
-- the role lowers none of them.
function M.weakened(role,e)
    if type(role)~='table' or type(e)~='table' then return nil end
    local by=type(role.saveBy)=='table' and role.saveBy or {}
    local resist=type(role.resist)=='table' and role.resist or {}
    local k=type(role.kinds)=='table' and role.kinds or {}
    local armor=number(e.ac) and amount(role,'armor') or 0
    if number(e.ac) and k.blind and not targeting.has(e.state,targeting.STATE.blind) then armor=armor+M.blindArmor end
    local mr=amount(role,'magicResistance')
    for _,cut in ipairs(type(role.mrCuts)=='table' and role.mrCuts or {}) do
        local current=(number(e.mr) and e.mr or 0)-mr
        mr=mr+math.max(cut.min,math.min(cut.max,math.floor(current*cut.share)))*cut.p
    end
    local saves=next(by)~=nil and type(e.saves)=='table'
    if not saves and next(resist)==nil and armor<=0 and mr<=0 then return nil end
    local c={}
    for key,v in pairs(e) do c[key]=v end
    if saves then
        c.saves={}
        for name,v in pairs(e.saves) do c.saves[name]=number(v) and number(by[name]) and v+by[name] or v end
    end
    if next(resist)~=nil then
        c.resist={}
        for name,v in pairs(type(e.resist)=='table' and e.resist or {}) do c.resist[name]=v end
        for label,v in pairs(resist) do
            local key=M.RESIST[label] or label
            if number(v) then c.resist[key]=(number(c.resist[key]) and c.resist[key] or 0)-v end
        end
    end
    if armor>0 then c.ac=e.ac+armor end
    if mr>0 then c.mr=math.max(0,(number(e.mr) and e.mr or 0)-mr) end
    return c
end
return M
