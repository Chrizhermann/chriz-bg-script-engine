-- The engine's own search for enemies a creature cannot see (Christopher, 2026-10-25: "Das können
-- wir doch auch einbauen? Vielleicht sogar geiler als SCS?"; his "ok" to the proposal the same
-- day). SCS is the blueprint ([src] genai/ssl/chase.ssl, mage/ssl/generalblocks/chase.ssl and
-- findhidden.ssl, credit DavidW): its creatures note the first party member they see; when they see
-- no enemy while their fight goes on, they walk for 8 to 15 seconds to where that party member
-- really is (MoveToObject), mages with Dimension Door teleport there and fighters open a near closed
-- door; mages and priests of higher levels cast a free Oracle, Detect Invisibility or Invisibility
-- Purge with a taunt when a hidden party member is near (Detect without See); then they give up.
--
-- Here the creature acts only on what it or its group perceived (fair play):
-- - clues: where the group last saw each enemy and which way it was going (seen), an enemy another
--   member sees now (sighted), a hit from an attacker it did not see, from where the attacker stood
--   (hit), and an enemy lost from sight on a spot the creature still sees (vanished: likely
--   invisible). The adapter marks a hit near when the creature sees the attacker's spot;
-- - detection: what the creature has (spells, abilities and items that take invisibility away or
--   let it see the invisible), when a clue says the enemy is likely invisible and the detection
--   reaches its spot; a rogue's Detect Illusion (its modal search) as well;
-- - the walk: to the best clue's point. A tactical creature leads a moving enemy along its last
--   heading, spreads out from members that search the same spot and, as a caster, stays behind a
--   fighter that searches it too;
-- - the jump: a long walk goes by a teleport the creature has, cast at the spot like any spell (SCS's
--   phase spiders and mind flayers teleport to the party member they do not see, its mages Dimension
--   Door after the one they chase; here the spot is the clue's, not where the party member really
--   is). An innate power anyone uses; a memorized spell, which spends its slot, only a creature that
--   sees its tactics, and only for a longer walk;
-- - patience: by wit, counted from the newest clue, halved for the wounded and the cowardly; then it
--   gives up: back to its post (where its fight began), where the engine heals as it does in a fight.
--   One that guards (a boss, or by its orders) searches only near its post;
-- - tactics by wit (mind.tactics): a clever creature always, a normal one when its search draws it
--   (once a search), a dull one never. Seeing that a vanished enemy turned invisible is a tactic;
--   a hit from an unseen attacker on a spot in sight tells anyone;
-- - foes out of play (combat-intent/director.lua's away: one the group charmed, one in a maze) are
--   awaited, not searched (Christopher, 2026-10-29), by wit: a clever creature guards the foe's spot
--   from a distance and strikes when it is back, a normal one waits at its post, a dull one forgets
--   it and stands where it is; a designer's orders can say which (await). Neither hands the round
--   back to SCS meanwhile: its last blocks attack the party even when charmed, and harming a charmed
--   foe breaks the charm by the rules text. A guard also renews its protections and buffs for when
--   the foe comes back (combat-intent/choice.lua's readiness), by when that is likely (M.mazeLeft).
-- Inputs are plain values; nothing here touches the engine.
local targeting=require('combat-intent.targeting')
local M={}
M.ticksPerSecond=15
-- Patience by wit: seconds a creature goes on searching after its newest clue (SCS: 8 to 15).
M.PATIENCE={clever=30,normal=18,dull=8}
-- Each halves the patience: hit points below woundedShare of the most, or a morale break at or
-- above cowardBreak (STATS.IDS MORALEBREAK; in the SR lab's 9,399 creature files mostly 5 or 7,
-- and 0 for the fearless).
M.woundedShare=0.5
M.cowardBreak=7
M.giveUpShare=0.5
-- Clues older than this are forgotten (the director forgets enemies after 30 seconds), unless the
-- creature's patience lasts longer: a patient creature keeps its clues while it searches.
M.memorySeconds=30
-- The best clue: by kind, then the newest, then the nearest.
M.PRIORITY={sighted=4,hit=3,vanished=2,seen=1}
-- A tactical creature leads a moving enemy by up to leadSeconds of its last heading, at most
-- leadMax world units.
M.leadSeconds=2
M.leadMax=150
-- Members that search the same spot keep spread apart; a caster stays holdBack short of a spot a
-- fighter searches too.
M.spread=80
M.holdBack=120
-- A spot counts as searched within arrive of it; the post as reached within postSlack.
M.arrive=48
M.postSlack=48
-- A creature that guards searches only clues within guardRadius of its post.
M.guardRadius=240
-- No new detection within detectGap seconds of the last. A buff that lets the creature see the
-- invisible works in its sight (sense.sightRange). A rogue's Detect Illusion counts from
-- illusionMin per cent and within illusionRange (what it reveals is still to be seen in a lab).
M.detectGap=6
M.sightRange=448
M.illusionMin=30
M.illusionRange=224
-- Families that cast rather than fight in melee.
M.CASTERS={mage=true,priest=true}
-- The group's picture as clues (M.kindOf): an enemy another member saw within sightedTicks is still
-- in its sight (members check in every 15 ticks); one lost from sight within vanishTicks on a spot
-- the creature sees vanished there.
M.sightedTicks=16
M.vanishTicks=30
-- An item that detects is used after every spell (M.options): its level for the ranking.
M.itemLevel=10
-- A search walk at least jumpMin long goes by an innate teleport, one at least jumpSlotMin long by
-- a memorized one (M.jump); no innate teleport within jumpGap seconds of the creature's last, no
-- memorized one within jumpSlotGap (SCS's mages wait 18 seconds between their Dimension Door
-- pursuits). The gap is the only pause for the game's Teleport Without Error, which most fiends
-- carry: it gives itself back at once (opcodes 172 and 171). The installer's BGSETELE comes back
-- after 18 seconds by itself, as the mind flayers' Planar Travel does (Christopher, 2026-10-26: an
-- instant teleport with a cooldown). Jumps into the fight count the same gap
-- (combat-intent/choice.lua).
M.jumpMin=200
M.jumpSlotMin=600
M.jumpGap=18
M.jumpSlotGap=18
-- A group's boss guards its post (M.boss): it has at least bossOthers other members, each at least
-- bossLead levels below it.
M.bossOthers=2
M.bossLead=2
-- How each wit awaits a foe out of play (M.await), and where a guard stands: guardNear from the
-- foe's spot (fighters and monsters, a step from striking) or guardFar (casters), on the side the
-- creature comes from, turned around the spot by guardTurn, one way and then the other, up to
-- guardTurns places, away from the spots other members make for.
M.AWAIT={clever='guard',normal='post',dull='stand'}
M.guardNear=96
M.guardFar=240
M.guardTurn=math.pi/4
M.guardTurns=8
-- A maze lasts rounds of roundSeconds (IESDP opcode 213); its dice are summed exactly while they
-- reach at most mazeOutcomes (the IESDP's table goes to 20d4), beyond that by their mean.
M.roundSeconds=6
M.mazeOutcomes=100

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function list(t) return type(t)=='table' and t or {} end
local function point(p) return type(p)=='table' and number(p.x) and number(p.y) end
local function whole(p) return {x=math.max(0,math.floor(p.x+0.5)),y=math.max(0,math.floor(p.y+0.5))} end

-- Whether the creature sees a tactic's chance in this search: input.tactical once the search has
-- drawn it (M.draw), else whether its chance (mind.tactics) is a half or more.
function M.tactical(input)
    if input.tactical~=nil then return input.tactical==true end
    local p=number(input.mind.tactics) and input.mind.tactics or 1
    return p>=0.5
end
-- The draw a search makes once: whether the creature uses its tactics this search (mind.tactics);
-- without rng, when its chance is a half or more.
function M.draw(m,rng)
    local p=type(m)=='table' and number(m.tactics) and m.tactics or 1
    if p>=1 then return true end
    if p<=0 then return false end
    if not rng then return p>=0.5 end
    return rng:nextInt(1,1000)<=math.floor(p*1000+0.5)
end

-- The creature's patience in seconds: its wit's (mind.searchPatience scales it for labs), halved
-- when it is wounded and again when it is cowardly.
function M.patience(input)
    local m=input.mind
    local p=M.PATIENCE[m.wit] or M.PATIENCE.normal
    if number(m.searchPatience) and m.searchPatience>=0 then p=p*m.searchPatience end
    local s=input.frame.self
    if number(s.hp) and number(s.maxHp) and s.maxHp>0 and s.hp<s.maxHp*M.woundedShare then p=p*M.giveUpShare end
    if number(s.moraleBreak) and s.moraleBreak>=M.cowardBreak then p=p*M.giveUpShare end
    return p
end

-- The kind of clue an enemy in the group's picture gives a creature that sees none: 'sighted' when
-- another member saw it (by) within sightedTicks (age), 'vanished' when it was lost from sight within
-- vanishTicks on a spot the creature sees (near), else 'seen'.
function M.kindOf(age,near,by)
    if by and age<=M.sightedTicks then return 'sighted' end
    if age<=M.vanishTicks and near then return 'vanished' end
    return 'seen'
end

-- Whether a creature of level is its group's boss (others: the other members' levels), which
-- guards its post.
function M.boss(level,others)
    if not number(level) or type(others)~='table' or #others<M.bossOthers then return false end
    for _,l in ipairs(others) do
        if not number(l) or l>level-M.bossLead then return false end
    end
    return true
end

-- One detection option from a classified spell or item ability c (combat-intent/spells.lua), or nil:
-- a buff of seeInvisible on the caster ('see'); a removal of invisibility through an area around the
-- caster ('purge', center 'self') or, for a spell, at a point it aims (center 'point', its range in
-- world units).
local function option(c,resref,level,item)
    if type(c)~='table' or type(c.roles)~='table' then return nil end
    local buff,removal=c.roles.buff,c.roles.removal
    local speed=number(c.speed) and c.speed or 0
    if type(buff)=='table' and type(buff.kinds)=='table' and buff.kinds.seeInvisible and type(buff.who)=='table' and
        buff.who.self then
        return {resref=resref,kind='see',level=level,speed=speed,item=item}
    end
    if type(removal)=='table' and type(removal.kinds)=='table' and removal.kinds.invisibility and
        type(removal.who)=='table' and removal.who.area and type(c.area)=='table' and number(c.area.radius) and
        c.area.radius>0 then
        if c.target=='self' then
            return {resref=resref,kind='purge',center='self',radius=c.area.radius,level=level,speed=speed,item=item}
        end
        if c.target=='point' and not item and number(c.range) then
            return {resref=resref,kind='purge',center='point',radius=c.area.radius,range=c.range*targeting.rangeUnit,
                level=level,speed=speed}
        end
    end
end
-- The detections a creature has ready (M.detection's options): its spells ready to cast (rows:
-- {resref, level, ready, usable, spell: the classification}) and the items it carries (carried:
-- {resref, abilities: {effect: the classification, uses}}), each item by its first ability, used on
-- the creature itself, while it has uses left. Spells Spell Revisions or other mods change count by
-- what they do: True Seeing with or without its own sight, Glitterdust at a point.
function M.options(rows,carried)
    local out={}
    for _,row in ipairs(list(rows)) do
        if type(row)=='table' and type(row.resref)=='string' and number(row.ready) and row.ready>0 and row.usable then
            local level=number(row.level) and row.level or (type(row.spell)=='table' and number(row.spell.level) and
                row.spell.level) or 9
            local o=option(row.spell,row.resref,level)
            if o then out[#out+1]=o end
        end
    end
    for _,it in ipairs(list(carried)) do
        local a=type(it)=='table' and type(it.abilities)=='table' and it.abilities[1]
        if type(a)=='table' and type(it.resref)=='string' and (a.uses==nil or (number(a.uses) and a.uses>0)) then
            local o=option(a.effect,it.resref,M.itemLevel,true)
            if o then out[#out+1]=o end
        end
    end
    return out
end

-- One teleport from a classified spell c (combat-intent/spells.lua), or nil: cast at a point, it
-- moves the caster there (opcode 124 or 274 on the caster: a phase spider's teleport, a mind
-- flayer's astral travel, Dimension Door). Its range in world units.
local function teleport(c,resref,level,innate)
    if type(c)~='table' or type(c.roles)~='table' or c.target~='point' or not number(c.range) or c.range<=0 then
        return nil
    end
    local move=c.roles.move
    if type(move)~='table' or type(move.kinds)~='table' or not move.kinds.teleport or type(move.who)~='table' or
        not move.who.self then return nil end
    return {resref=resref,level=level,range=c.range*targeting.rangeUnit,speed=number(c.speed) and c.speed or 0,
        innate=innate or nil}
end
-- The teleports a creature has ready (M.jump's options): its spells ready to cast (rows, as for
-- M.options), innate when they come from its innate abilities (list 'innate'). Whatever moves the
-- caster to a point counts, with or without Spell Revisions.
function M.teleports(rows)
    local out={}
    for _,row in ipairs(list(rows)) do
        if type(row)=='table' and type(row.resref)=='string' and number(row.ready) and row.ready>0 and row.usable then
            local level=number(row.level) and row.level or (type(row.spell)=='table' and number(row.spell.level) and
                row.spell.level) or 9
            local o=teleport(row.spell,row.resref,level,row.list=='innate')
            if o then out[#out+1]=o end
        end
    end
    return out
end

-- The teleport that takes the creature toward p, walk world units away, or nil: an innate one from
-- jumpMin on, a memorized one from jumpSlotMin on for a tactical creature; none within its gap of
-- the creature's last teleport (input.jumped; with no clock to count it, none at all). The innate
-- first, then the lowest level, then the name. Returns the option and where it lands: p, or as far
-- toward p as it reaches.
function M.jump(input,p,walk,tactical)
    local self=input.frame.self
    local chosen,chosenKey
    for _,o in ipairs(list(input.teleports)) do
        if type(o)=='table' and type(o.resref)=='string' and number(o.range) and o.range>0 then
            local gap=(o.innate and M.jumpGap or M.jumpSlotGap)*M.ticksPerSecond
            local recent=number(input.jumped) and not (number(input.tick) and input.tick-input.jumped>=gap)
            if walk>=(o.innate and M.jumpMin or M.jumpSlotMin) and (o.innate or tactical) and not recent then
                local k={o.innate and 1 or 0,-(number(o.level) and o.level or 9)}
                local better=chosen==nil
                if not better then
                    for i=1,#k do
                        if k[i]~=chosenKey[i] then better=k[i]>chosenKey[i];break end
                    end
                    if not better and k[1]==chosenKey[1] and k[2]==chosenKey[2] and o.resref<chosen.resref then better=true end
                end
                if better then chosen,chosenKey=o,k end
            end
        end
    end
    if not chosen then return nil end
    local at={x=p.x,y=p.y}
    if walk>chosen.range then
        local k=chosen.range/walk
        at={x=self.x+(p.x-self.x)*k,y=self.y+(p.y-self.y)*k}
    end
    return chosen,whole(at)
end

-- The key a clue is searched under: its enemy (or its spot) and when it was seen.
function M.key(clue)
    local who=number(clue.id) and tostring(clue.id) or ('@'..math.floor(clue.x)..','..math.floor(clue.y))
    return clue.kind..':'..who..':'..clue.tick
end

-- The clues worth acting on: well formed, not from the future, not forgotten (kept for
-- memorySeconds, or longer while the creature's patience lasts), not of a foe out of play.
local function current(input,patience)
    local horizon=math.max(M.memorySeconds,patience)*M.ticksPerSecond
    local away={}
    for _,a in ipairs(list(input.away)) do if type(a)=='table' and a.id~=nil then away[a.id]=true end end
    local out={}
    for _,c in ipairs(list(input.clues)) do
        if type(c)=='table' and M.PRIORITY[c.kind] and point(c) and number(c.tick) and c.tick<=input.tick and
            input.tick-c.tick<=horizon and not (c.id~=nil and away[c.id]) then out[#out+1]=c end
    end
    return out
end

-- The best clue not searched yet: by kind, then the newest, then the nearest; ties by key.
local function best(input,clues,searched)
    local self=input.frame.self
    local chosen,chosenKey
    for _,c in ipairs(clues) do
        local key=M.key(c)
        if not searched[key] then
            local k={M.PRIORITY[c.kind],c.tick,-targeting.distance(self,c)}
            local better=chosen==nil
            if not better then
                for i=1,#k do
                    if k[i]~=chosenKey[i] then better=k[i]>chosenKey[i];break end
                end
            end
            if better then chosen,chosenKey=c,k end
        end
    end
    return chosen
end

-- Whether clue says its enemy is likely invisible near the creature, on a spot the creature sees
-- (near) with no one there: a hit from such a spot tells anyone; an enemy that vanished there, or
-- one another member sees there, tells a tactical creature.
local function hidden(clue,tactical)
    if clue.near~=true then return false end
    if clue.kind=='hit' then return true end
    return (clue.kind=='vanished' or clue.kind=='sighted') and tactical
end

-- The detection that reaches clue's spot, the cheapest first: a buff that lets the creature see the
-- invisible (o.kind 'see', within its sight), an area that takes invisibility around it (o.kind
-- 'purge', o.center 'self', within o.radius) or at a point it can reach (o.center 'point', within
-- o.range and o.radius beyond). At equal levels the buff, which lasts, comes first. Returns the
-- option and where it goes: 'self' or a point.
function M.detection(input,clue)
    local self=input.frame.self
    local d=targeting.distance(self,clue)
    local chosen,chosenKey,where
    local ORDER={see=3,self=2,point=1}
    for _,o in ipairs(list(input.detects)) do
        local at
        if type(o)=='table' and type(o.resref)=='string' then
            if o.kind=='see' and d<=M.sightRange then at='self'
            elseif o.kind=='purge' and o.center=='self' and number(o.radius) and d<=o.radius then at='self'
            elseif o.kind=='purge' and o.center=='point' and number(o.radius) and number(o.range) and d<=o.range+o.radius then
                if d<=o.range then at={x=clue.x,y=clue.y}
                else
                    -- As far as the spell reaches toward the spot: the area takes in the rest.
                    local k=o.range/d
                    at={x=self.x+(clue.x-self.x)*k,y=self.y+(clue.y-self.y)*k}
                end
                at=whole(at)
            end
        end
        if at then
            local level=number(o.level) and o.level or 9
            local k={-level,ORDER[o.kind=='see' and 'see' or o.center] or 0}
            local better=chosen==nil
            if not better then
                for i=1,#k do
                    if k[i]~=chosenKey[i] then better=k[i]>chosenKey[i];break end
                end
                if not better and k[1]==chosenKey[1] and k[2]==chosenKey[2] and o.resref<chosen.resref then better=true end
            end
            if better then chosen,chosenKey,where=o,k,at end
        end
    end
    return chosen,where
end

-- Where the creature walks for clue: its spot, led along the enemy's heading by a tactical creature;
-- a tactical caster stays holdBack short of a spot a fighter of its group searches too, and a
-- tactical creature spreads out from members already searching the spot (a ring around it, the
-- first two to the sides, then beyond and short of it).
function M.aim(input,clue,tactical)
    local self=input.frame.self
    local p={x=clue.x,y=clue.y}
    if tactical and number(clue.vx) and number(clue.vy) then
        local t=math.min(M.leadSeconds,math.max(0,(input.tick-clue.tick)/M.ticksPerSecond))
        local dx,dy=clue.vx*t,clue.vy*t
        local len=math.sqrt(dx*dx+dy*dy)
        if len>M.leadMax then dx,dy=dx*M.leadMax/len,dy*M.leadMax/len end
        p.x,p.y=p.x+dx,p.y+dy
    end
    if not tactical then return whole(p) end
    local group=list(input.group)
    if M.CASTERS[input.family] then
        local fighter=false
        for _,o in ipairs(group) do
            if type(o)=='table' and not M.CASTERS[o.family] and point(o.point) and targeting.distance(o.point,p)<=M.spread*2 then
                fighter=true
            end
        end
        if fighter then
            local d=targeting.distance(self,p)
            if d<=M.holdBack then return whole(self) end
            local k=(d-M.holdBack)/d
            p={x=self.x+(p.x-self.x)*k,y=self.y+(p.y-self.y)*k}
        end
    end
    local rank=0
    for _,o in ipairs(group) do
        if type(o)=='table' and point(o.point) and targeting.distance(o.point,p)<M.spread then rank=rank+1 end
    end
    if rank>0 then
        local ax,ay=p.x-self.x,p.y-self.y
        local len=math.sqrt(ax*ax+ay*ay)
        if len<1 then ax,ay,len=1,0,1 end
        ax,ay=ax/len,ay/len
        local ring=math.floor((rank-1)/4)+1
        local side=(rank-1)%4
        local ox,oy
        if side==0 then ox,oy=-ay,ax elseif side==1 then ox,oy=ay,-ax elseif side==2 then ox,oy=ax,ay else ox,oy=-ax,-ay end
        p.x,p.y=p.x+ox*M.spread*ring,p.y+oy*M.spread*ring
    end
    return whole(p)
end

-- Where a creature guards a foe out of play at a: guardNear from its spot (guardFar for a caster), as
-- targeting.distance counts it, on the side the creature stands, turned around the spot by guardTurn
-- one way and then the other to the first place no other member of the group makes for within
-- spread (group: {point}); the first place when all are taken.
function M.guardPoint(input,a)
    local self=input.frame.self
    local r=M.CASTERS[input.family] and M.guardFar or M.guardNear
    -- Turned in the space targeting.distance measures, where y counts 4/3.
    local ux,uy=self.x-a.x,(self.y-a.y)*4/3
    local len=math.sqrt(ux*ux+uy*uy)
    if len<1 then ux,uy,len=1,0,1 end
    ux,uy=ux/len,uy/len
    local group=list(input.group)
    local first
    for i=0,M.guardTurns-1 do
        local t=math.ceil(i/2)*(i%2==1 and 1 or -1)*M.guardTurn
        local c,s=math.cos(t),math.sin(t)
        local p={x=a.x+(ux*c-uy*s)*r,y=a.y+(ux*s+uy*c)*r*3/4}
        first=first or p
        local taken=false
        for _,o in ipairs(group) do
            if type(o)=='table' and point(o.point) and targeting.distance(o.point,p)<M.spread then taken=true end
        end
        if not taken then return whole(p) end
    end
    return whole(first)
end

local HOWS={guard=true,post=true,stand=true}
-- The nearest of the foes out of play (input.away: {id, kind 'charm' or 'maze', x, y}) to the
-- creature (input.frame.self), or nil when there are none.
function M.nearestAway(input)
    local self=input.frame.self
    local foe,best
    for _,a in ipairs(list(input.away)) do
        if type(a)=='table' and (a.kind=='charm' or a.kind=='maze') and point(a) and number(a.id) then
            local d=targeting.distance(self,a)
            if foe==nil or d<best or (d==best and a.id<foe.id) then foe,best=a,d end
        end
    end
    return foe
end
-- How the creature awaits foe, one out of play: by its orders (input.await: 'guard', 'post' or
-- 'stand'), else its wit (M.AWAIT); one that guards its post (input.guard) guards only a foe within
-- guardRadius of the post (input.post) and otherwise waits there.
function M.how(input,foe)
    local how=HOWS[input.await] and input.await or M.AWAIT[type(input.mind)=='table' and input.mind.wit] or M.AWAIT.normal
    local post=point(input.post) and input.post or nil
    if how=='guard' and input.guard and not (post and targeting.distance(post,foe)<=M.guardRadius) then how='post' end
    return how
end
-- How the creature awaits the foes out of play, or nil when there are none: the nearest of them
-- (M.nearestAway), as M.how says. A guard walks to its place by the foe (M.guardPoint) and looks out
-- there. One that waits at its post walks back there and looks out; one that stands, and any rooted
-- one, looks out where it is. The decision: {kind 'guard' or 'return' (with point) or 'look', await
-- and target (the foe's id), away (its kind), how, point (a guard's place), gaveUp}.
function M.await(input,gaveUp)
    local self=input.frame.self
    local foe=M.nearestAway(input)
    if not foe then return nil end
    local how=M.how(input,foe)
    local post=point(input.post) and input.post or nil
    local d={await=foe.id,target=foe.id,away=foe.kind,how=how,gaveUp=gaveUp or nil}
    if self.rooted then d.kind='look';return d end
    if how=='guard' then
        d.point=M.guardPoint(input,foe)
        d.kind=targeting.distance(self,d.point)>M.arrive and 'guard' or 'look'
        return d
    end
    if how=='post' and post and targeting.distance(self,post)>M.postSlack then
        d.kind,d.point='return',whole(post)
        return d
    end
    d.kind='look'
    return d
end

-- The seconds a maze is still likely to last, elapsed seconds after it began, while its foe is not
-- back: the mean of what is left of the durations still possible, as num dice of size rounds give
-- them (a maze by intelligence, IESDP opcode 213: the dice INTMOD.2DA gives the foe's
-- intelligence). The caster's side knows how the spell works, not what its dice rolled (fair play).
-- 0 once no duration is left; nil for dice that make none.
function M.mazeLeft(num,size,elapsed)
    if not number(num) or not number(size) or num<1 or size<1 or num%1~=0 or size%1~=0 then return nil end
    elapsed=number(elapsed) and math.max(0,elapsed) or 0
    local r=M.roundSeconds
    if num*size>M.mazeOutcomes then return math.max(0,num*(size+1)/2*r-elapsed) end
    -- The chance of each sum, die by die.
    local p,lo,hi={[0]=1},0,0
    for _=1,num do
        local q={}
        for s=lo+1,hi+size do q[s]=0 end
        for s=lo,hi do
            for face=1,size do q[s+face]=q[s+face]+p[s]/size end
        end
        p,lo,hi=q,lo+1,hi+size
    end
    local mass,sum=0,0
    for s=lo,hi do
        local left=s*r-elapsed
        if left>0 then mass=mass+p[s];sum=sum+p[s]*left end
    end
    if mass<=0 then return 0 end
    return sum/mass
end

-- What the creature does while it sees no enemy, or nil and why not:
-- {kind='detect', resref, self=true or point, level, item, slot, speed, clue, target, key},
-- {kind='modal', clue, target, key} (Detect Illusion), {kind='search', point, clue, target, key},
-- {kind='teleport', resref, point, toward, level, speed, innate, clue, target, key} (a jump: point
-- where it lands, toward the spot a walk would go to), {kind='look', key} (on a searched spot, or
-- kept at its post or rooted),
-- {kind='return', point} (given up, or kept near its post: back there); while foes are out of play
-- and nothing else is left to search, how it awaits them (M.await: a 'guard' walk, a 'return' or a
-- 'look' with await set).
-- input: tick; frame (self: x, y, hp, maxHp, moraleBreak, seeInvisible, rooted; enemies empty);
-- mind (wit, tactics, searchPatience); family; clues; post; since (the tick its search began, if
-- it searches); searched (keys of searched spots); gaveUp (the tick the creature gave up, if it
-- did); detected (the tick of its last detection); jumped (the tick of its last teleport);
-- group (other members: {id, family, point}); guard; detects (see M.detection); teleports (see
-- M.jump); illusion (its Detect Illusion skill); tactical (M.draw's, once a search); away (foes out
-- of play, M.await) and await (its orders' way to await them).
-- The decision says what the adapter keeps: searched (a key now searched), gaveUp (true when the
-- creature gives up now).
function M.decide(input)
    if type(input)~='table' or type(input.frame)~='table' or type(input.frame.self)~='table' or
        type(input.mind)~='table' or not number(input.tick) then return nil,'bad-input' end
    local self=input.frame.self
    if not point(self) then return nil,'bad-input' end
    local patience=M.patience(input)
    local clues=current(input,patience)
    local post=point(input.post) and input.post or nil
    local function back(gaveUp)
        local d=M.await(input,gaveUp)
        if d then return d end
        if post and targeting.distance(self,post)>M.postSlack and not self.rooted then
            return {kind='return',point=whole(post),gaveUp=gaveUp or nil}
        end
        return nil,'given-up'
    end
    local newest
    for _,c in ipairs(clues) do if not newest or c.tick>newest then newest=c.tick end end
    if not newest then
        -- Nothing to go on: one that searched goes back to its post; foes out of play are awaited.
        if number(input.gaveUp) or number(input.since) then return back(not number(input.gaveUp)) end
        local d=M.await(input)
        if d then return d end
        return nil,'no-clue'
    end
    -- Given up, and nothing new since: back to the post, then the creature's own life.
    if number(input.gaveUp) and newest<=input.gaveUp then return back() end
    if (input.tick-newest)/M.ticksPerSecond>patience then return back(true) end
    local tactical=M.tactical(input)
    local searched=type(input.searched)=='table' and input.searched or {}
    local clue=best(input,clues,searched)
    if not clue then return {kind='look'} end
    local key=M.key(clue)
    -- Detection, when the clue says the enemy is likely invisible here and the creature does not
    -- see the invisible already.
    if hidden(clue,tactical) and not self.seeInvisible and
        not (number(input.detected) and input.tick-input.detected<M.detectGap*M.ticksPerSecond) then
        local o,where=M.detection(input,clue)
        if o then
            local d={kind='detect',resref=o.resref,level=o.level,item=o.item,slot=o.slot,speed=o.speed,clue=clue.kind,
                target=clue.id,key=key}
            if where=='self' then d.self=true else d.point=where end
            return d
        end
        if number(input.illusion) and input.illusion>=M.illusionMin and tactical and
            targeting.distance(self,clue)<=M.illusionRange then
            return {kind='modal',clue=clue.kind,target=clue.id,key=key}
        end
    end
    if input.guard and post and targeting.distance(post,clue)>M.guardRadius then
        if targeting.distance(self,post)>M.postSlack and not self.rooted then return {kind='return',point=whole(post)} end
        return {kind='look',key=key,guard=true}
    end
    if self.rooted then return {kind='look',key=key,rooted=true} end
    local p=M.aim(input,clue,tactical)
    local walk=targeting.distance(self,p)
    if walk<=M.arrive then return {kind='look',key=key,searched=key} end
    local o,at=M.jump(input,p,walk,tactical)
    if o then
        return {kind='teleport',resref=o.resref,point=at,toward=p,level=o.level,speed=o.speed,innate=o.innate,
            clue=clue.kind,target=clue.id,key=key}
    end
    return {kind='search',point=p,clue=clue.kind,target=clue.id,key=key}
end
return M
