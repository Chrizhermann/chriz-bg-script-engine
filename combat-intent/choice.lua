-- The engine's own choice of an attack spell and its target or aim point for one caster (step
-- 3, second slice; Christopher's answers of 2026-10-18 are in the plan). Inputs are plain
-- values: the caster's perception frame with enemy details (adapters/eeex/sense.lua), its
-- ready and usable spells classified by combat-intent/spells.lua, the fight director's plan,
-- what it remembers about casts that had no effect, and its profile (combat-intent/mind.lua).
-- Nothing here touches the engine. Odd data drops one option, never the whole choice.
--
-- The round (Christopher, 2026-10-25: "wir müssen SCS nichts überlassen", and what is quick does
-- not take the round): the engine leaves no round to SCS. While the casting aura of the last cast
-- runs, casts and drinks wait for it; an attack is made meanwhile when it is worth more than the
-- part of the best cast it holds back, a walk into position for that cast (below) when it is worth
-- more than such an attack, else the creature waits until the aura frees. With nothing worth doing
-- it waits a moment and decides again. A fighter or monster attacks whenever nothing else is worth
-- more (mind.alwaysAttack); a caster that has no attack worth anything takes the best spell that is
-- worth something.
--
-- Buff potions (Christopher, 2026-10-29: the first one right at the start of the fight; a potion
-- takes no round, the creature still attacks and moves): a drink takes a moment, and the attack
-- follows it. So where the creature would attack, the best drink that adds to attacks (Oil of
-- Speed, giant strength) comes first when it is worth more than the part of the attack its moment
-- takes, with no minimum worth: the creature does not leave its weapon for it. Healing and
-- protection potions are weighed against the attack as before (his call, later, with how long a
-- drink should take). An ability without casting time (speed 0) that strengthens the creature's
-- own attacks counts as such a moment too (Christopher, 2026-10-25: abilities used "instant" need
-- not take the whole round): a kensai's Ki Focus before its swing, as a drink.
--
-- Worth is counted in shares of an enemy taken out of the fight: the hit points a cast takes
-- (as a share of the enemy's maximum, no more than it has left), the worth of a kill, or the
-- chance and length of a disable. A spell's level costs a little, so small spells do small
-- jobs. An attack must reach the profile's minimum worth.
--
-- Walking into range (R3: with no round left to SCS, an enemy out of range is no reason to wait):
-- a spell aimed beyond its range is cast after a walk into range, as the game's spell actions walk
-- there first. The walk lowers the worth as a walk to a melee enemy does, and an area must keep
-- the caster out where the walk ends. Not for a cone, a release or a caster that cannot walk; an
-- area around the caster goes off where it stands.
--
-- Positioning in the casting pause (Christopher, 2026-10-25: walking into position during the
-- casting cooldown, by wit, "zwischen taktisch klugen Gegnern und taktisch dummen Gegnern zu
-- unterscheiden"): while the casting aura runs and the cast the creature will make once it frees
-- needs a walk into range, it walks toward the spot it will cast from meanwhile, never to where an
-- enemy's melee weapon reaches, so that the cast goes off sooner (M.position). It is weighed
-- against an attack meanwhile. A tactic (M.tactical): a clever creature always, a normal one when
-- it notices, a dull one never.
--
-- Since the third slice (Christopher, 2026-10-19) the caster's protections and buffs compete on
-- the same scale (combat-intent/defence.lua): the best option of either kind is cast. Openers
-- (combat-intent/openers.lua: Time Stop, Improved Alacrity) come first, as in SCS's order. In the
-- caster's own Time Stop its enemies stand frozen, and what it casts lands when time resumes:
-- the enemies it has disabled in the stop count as disabled, the damage it dealt them as dealt.
-- Under Improved Alacrity slow spells wait while a quick one is good enough, as SCS's do.
--
-- Touch charges (D2c, combat-intent/touch.lua): a touch spell is cast on the caster and aimed at
-- the enemy it will strike, worth what its hit does there times the chance to hit, less what
-- standing next to that enemy costs. A charge in hand is struck first, again until it lands.
-- Neither in the caster's own Time Stop nor under Improved Alacrity, as SCS keeps weapons out of
-- both.
--
-- Weapon attacks (D2c, combat-intent/weapons.lua; Christopher, 2026-10-20): the weapon in the
-- caster's hand, conjured or not, is worth a round of its hits on the enemy it attacks, less what
-- standing next to that enemy costs for melee. The walk to a melee enemy comes first and lowers
-- the worth; every creature walks to any enemy it sees (F1d), casters as SCS's mages do between
-- casts (E8 v5). It spends nothing, so it needs no minimum worth:
-- when no spell reaches minValue, the engine attacks. A spell
-- that conjures a weapon is worth the hits the weapon deals in the rounds after, as many as it
-- lasts within the horizon. Neither in the caster's own Time Stop nor under Improved Alacrity.
-- Releases (D2b): SCS's sequencers and triggers are innates that cast their spells at once. The
-- classifier reads them as their spells together, with the reach of the shortest
-- (combat-intent/spells.lua); their options carry release, and the adapter sets them off with
-- ForceSpellRES as SCS does. None under Improved Alacrity, as SCS keeps them for after it.
--
-- Healing and curing (D3a, D3b; Christopher, 2026-10-20: "Mach alles"): heals and cures for the
-- caster and its allies, and potions, compete on the same scale (combat-intent/care.lua). The
-- engine no longer leaves a hurt group or a silenced caster to SCS.
--
-- Summons (D3c): the creatures a summoning spell brings, by their fight on the caster's side,
-- compete on the same scale (combat-intent/summons.lua).
--
-- Protection removal (D3d): breaching, dispelling and stripping enemies and unsummoning summoned
-- ones compete on the same scale (combat-intent/removal.lua). An attack that also removes (Spell
-- Revisions' Chromatic Orb takes haste, Disintegrate destroys some creatures) stays an attack and
-- adds what its removal is worth on each enemy it hits. SCS keeps no round for spells of its own
-- (its scripts never raise).
--
-- Danger zones (D3e, combat-intent/zones.lua): clouds and storms around the caster count in every
-- option. Harm from them can break a cast where it stands; a melee attack or a strike counts what
-- walking to its target and standing there does in them. A way out of a zone that hurts the
-- caster comes first when what leaving is worth beats the share of a round the walk takes from
-- the best other choice. How much of this a creature sees is its wit (combat-intent/mind.lua): a
-- dull one counts no zone and leaves only when the pain drives it out, then whatever else it
-- could do.
--
-- Lasting areas (D3e; Christopher, 2026-10-23: "Ich würde eine Mischung aus A und C machen"): a
-- cloud or storm of the caster's own counts the explosions each enemy inside is expected to sit
-- through, not one. The first goes off where it lands (unless the projectile skips it), the next
-- every few seconds while it lasts; one that Spell Revisions' clouds make immune to them for a
-- while is hit when that wears off (combat-intent/zones.lua, period). Only explosions in the rest
-- of the fight count (combat-intent/threat.lua, rest), the first always, and those the enemy's
-- turnings, deflections and traps stop come first. An enemy that cannot walk sits through all of
-- them. Any other takes the cheaper of staying and walking out (A): out, it takes the explosions
-- until it is out, starting M.react seconds after the landing, and loses the walk's seconds as a
-- hold of that length. Some enemies stay anyway (C): the chance an enemy stays is what the group
-- has seen it do in zones that hurt it (input.stays: the explosions it stayed for and the zones it
-- left, adapters/eeex/choice.lua), from M.stayPrior worth M.stayWeight sightings. An ally or the
-- caster may stand in the caster's own area when the area does nothing to it. The profile's
-- clouds switch: 'learned', 'best' (A alone) or 'once' (one explosion, as before).
--
-- Orders (combat-intent/orders.lua; Christopher, 2026-10-25): a designer's target order makes what
-- the creature's attacks do to the enemy it names count more, or keeps its attacks on that enemy
-- while it can attack it at all.
--
-- Interrupting (Christopher, 2026-10-25: worth decides, with a bonus for interrupting an enemy that
-- is casting): damage that lands while an enemy casts breaks its spell, and its spell slot stays
-- spent (ACT-03, batch H5). The creature may know the spell, as SCS's scripts can learn it from the
-- game's SpellCast triggers: an enemy carries cast {level, speed, timer} while it casts in a way
-- damage can break (adapters/eeex/choice.lua). Breaking the spell is worth mind.interrupt for each
-- of its levels, times the chance the attack's damage lands while the casting runs
-- (M.castWindow). Only damage counts yet; whether a hold, sleep or silence breaks a cast is open.
-- How often a creature sees the chance is its wit (mind.tactics): a clever one always, a normal
-- one in half its decisions, a dull one never.
--
-- Jumps into the fight (Christopher, 2026-10-26: a real ability, named in the log and with a
-- cooldown, instead of SCS's scripted jump; SCS's fiends jump to a party member who is weak, a mage
-- or easy to hit, [src] fiend/ssl/jump.ssl, credit DavidW): a creature that walks to any enemy it
-- sees for its melee weapon (mind.chase) may cast a teleport it has (input.teleports,
-- combat-intent/search.lua) at a spot next to an enemy a long walk away instead, picked as the
-- search picks one: an innate teleport for a walk of search.jumpMin or more, a memorized spell
-- from search.jumpSlotMin on, none within search.jumpGap of its last teleport (input.jumped). It
-- is worth the round of hits it brings without the walk, and costs what a spell of its level costs
-- and what standing next to the enemy costs. As it ends next to the enemy like the walk, a creature
-- that always attacks takes it over the walk whenever it is worth more. A tactic (M.tactical): a
-- clever creature always, a normal one when it notices, a dull one never.
--
-- Debuffs (F2b; SCS's priests curse with Doom and Greater Malison an enemy not doomed or malisoned
-- yet, its mages slow the strongest enemy not slowed yet, [src] priest/ssl/combatblocks/doom.ssl,
-- curse_malison.ssl, mage/ssl/combatblocks/slow.ssl): a spell that weakens enemies (Slow, Doom,
-- blindness, Miscast Magic, a level drain) is an attack worth the share of each enemy's fight it
-- takes while it holds (combat-intent/harm.lua: its weapon against the mean armour class of the
-- caster's side, and its spells), as a disable is worth the share it takes out. A debuff that comes
-- with damage or a disable (Holy Smite blinds, Unholy Blight curses) adds its worth on each enemy,
-- beside a disable only as likely as the disable fails: a creature held has no fight to weaken. An
-- enemy that only the debuff of a spell reaches (Holy Word deafens those too strong for its death
-- and confusion) counts for the debuff. Nothing on an enemy that carries the spell's effects already
-- (its wards come from the spell, harm.carries), nor for slowing the slowed or blinding the blind.
-- Removal that comes with a debuff (Spell Revisions' Slow takes haste, Glitterdust and Faerie Fire
-- take invisibility) makes the spell an attack that adds what its removal is worth, as for damage.
-- Every creature casts debuffs; seeing what they open is a tactic (below).
--
-- Openings (F2b; Christopher, 2026-10-26: every new tactic by wit): a debuff that lowers an enemy's
-- saving throws, magic resistance, resistances or armour class (Greater Malison, Lower Resistance,
-- Faerie Fire, blindness) also counts what it opens for the attacks after it: the most one of the
-- caster's other ready attack spells gains on the weakened enemy (harm.weakened), and what the
-- weapons of its friends gain on it over the rounds the debuff holds (those next to the enemy, and
-- those with missiles when it is the group's focus), both as likely as the debuff lands. A tactic
-- (M.tactical): a clever creature always, a normal one when it notices, a dull one never.
--
-- Weapon choice (F2c; Christopher, 2026-10-26: archers next; SCS's archers shoot while no enemy
-- stands close and take up their most damaging melee weapon when one does, [src] genai/ssl/
-- shoot.ssl, dw#wtacor.ssl, credit DavidW): every weapon in the caster's weapon slots is an attack
-- option (frame.self.arsenal, combat-intent/arsenal.lua), weighed as the one in hand is, less the
-- second it takes to take it up (weapons.switchSeconds, as a walk that long lowers the worth), so a
-- creature changes its weapon only for one clearly better. A missile weapon walks into its range
-- first, as the game's attack actions do, and is no option against an enemy that keeps its
-- missiles off (weapons.missileBlocked). A magic weapon in hand stays there, as the game keeps it.
--
-- Body weapons (Christopher, 2026-11-10: a creature the engine takes over must not become simpler
-- than it was, and keeps what it was known for; the game's own scripts of ankhegs, wyverns, ettercaps
-- and basilisks picked one of their two attacks by chance, 40 to 60 or the like): a weapon the
-- creature cannot lay down (arms.body, combat-intent/arsenal.lua: a bite and a spit, a sting, a gaze)
-- is part of it, and it uses them all. Taking one up costs no time. When its best attack is made with
-- one of them, it takes that one as often as it takes its best option at all (mind.best, by its wit),
-- and otherwise draws among the best attacks of each of them, each as likely as its worth's share
-- (M.varied; mind.bodyMix scales it, 0 for always the best). So a wyvern stings and bites, the
-- deadlier attack more often, a clever creature the best one most. One that shoots (a spit, a gaze)
-- steps back from melee to use it whatever its wit (mind.bodyRetreat), as an ankheg and a basilisk
-- did by their scripts; for other creatures the step stays a tactic (kiting, below).
--
-- Kiting (F2c; SCS's ranged fighters run from an enemy within 6 for four seconds, once in
-- eighteen, then stand and fight, [src] genai/ssl/retreat.ssl, dw#range.ssl): a creature with a
-- missile weapon it can shoot steps away from the melee enemies close to it, worth the hits it keeps
-- off for the seconds of the step (its caution weighs them), when that beats the part of a round of
-- its best attack the step costs. A tactic (M.tactical): a clever creature always, a normal one when
-- it notices, a dull one never. Casters too (Christopher, 2026-11-03: mages step away from melee
-- foes now and then, by wit; SCS's mages step away from a melee foe close by while they still have
-- missile spells): a creature with a spell ready steps away as well, and when its best choice is a
-- cast that damage can break, the step is also worth that cast by how much less likely a melee hit
-- breaks it after the step than where it stands. A melee enemy that attacks the creature follows it,
-- a moment late (M.react); the others stay where they are.
--
-- Blocked moves (lab batch E8 v4: Tarnesh's step away from the inn's wall ended in a dead-end
-- corridor out of sight of everyone): a step away, a walk behind an enemy or a walk into position
-- that the adapter found no open way for lately (input.blocked: kite, position, flank by enemy) is
-- left out, so that the creature does something else where it stands.
--
-- Backstabs (F2d; SCS's thieves drink invisibility when they see an enemy, then stab the weakest
-- close enemy without Mirror Images or Stoneskin, [src] genai/ssl/backstab.ssl, dw#wtacor.ssl,
-- credit DavidW): an invisible creature's first hit from behind its target multiplies the weapon's
-- damage (combat-intent/backstab.lua). Every attack with a weapon that can backstab counts it, as
-- likely as the first swing lands from behind (by the target's facing; 5 in 16 when unknown). Going
-- behind an enemy that faces the creature first (a walk to the spot behind it, M.flankOptions), and
-- hiding to backstab next round (an invisibility potion, scroll or spell counts what the backstab
-- after it gains, M.hideOpening) are tactics (M.tactical): a clever creature always, a normal one
-- when it notices, a dull one never.
--
-- Freeing (Christopher, 2026-10-29: clever creatures free a member of their group whom the party
-- charmed, with Dispel Magic when they have it): a removal that takes the charm off an enemy the
-- other side charmed frees it (combat-intent/removal.lua). A tactic (M.tactical): a clever creature
-- always, a normal one when it notices, a dull one never; one that does not see it weighs the
-- removal as on any enemy.
--
-- Readiness (Christopher, 2026-10-29: clever creatures guard a mazed foe's spot, "heal and re-buff"
-- and strike when it comes back): while the creature sees no enemy and guards a foe out of play
-- (combat-intent/search.lua's how), the adapter names those foes as they will stand when back
-- (input.returning, M.readied); its protections and buffs count against them from when the first is
-- likely back on, as in its own Time Stop (combat-intent/defence.lua's calm). A buff that runs out
-- before then is worth nothing yet and is cast later, when it still lasts into the fight; one that
-- protects for hours is renewed at once. A summons waits where the foes went and fights from the
-- first one's return on (combat-intent/summons.lua); and a cloud or storm laid on the spot where a
-- mazed foe will be back counts the explosions from its likely return on (lastingOn; Christopher,
-- 2026-10-29: "Was für eine geile Idee"). Nothing else of the attacks counts before the foes are
-- back, and no area that would harm a foe the caster's side charmed. Only what reaches the minimum
-- worth is cast; the rest of the waiting rounds go to the guard. Normal creatures wait at their
-- post and only heal; dull ones forget the foe.
local targeting=require('combat-intent.targeting')
local harm=require('combat-intent.harm')
local defence=require('combat-intent.defence')
local care=require('combat-intent.care')
local summons=require('combat-intent.summons')
local removal=require('combat-intent.removal')
local zones=require('combat-intent.zones')
local threat=require('combat-intent.threat')
local openers=require('combat-intent.openers')
local touch=require('combat-intent.touch')
local weapons=require('combat-intent.weapons')
local spells=require('combat-intent.spells')
local orders=require('combat-intent.orders')
local search=require('combat-intent.search')
local backstab=require('combat-intent.backstab')
local M={}
M.rangeUnit=targeting.rangeUnit
-- Allies keep this much room beyond an area's edge; positions are up to a check-in old.
M.allyMargin=32
-- Worth of one spell level, times the profile's economy.
M.costPerLevel=0.03
-- A disable lasting this long counts in full (three rounds).
M.fullSeconds=harm.fullSeconds
-- STATE_SILENCED, in the active state.
M.SILENCED=0x1000
local UNSEEN=targeting.STATE.invisible+targeting.STATE.improvedInvisible
-- What each kind of disable is worth on an enemy, which kinds take it out for good, which matter
-- only against casters, and the resistance each damage type meets (combat-intent/harm.lua).
M.DISABLE=harm.DISABLE
M.FOR_GOOD=harm.FOR_GOOD
M.CASTERS_ONLY=harm.CASTERS_ONLY
M.RESIST=harm.RESIST
-- Roles that make a spell something other than an attack: healing, curing, raising, summoning,
-- and protection removal unless the spell also attacks, are other decisions.
local OTHER={'removal','heal','raise','cure','summon'}
local GLOBAL={everyone=true,nonparty=true,casterGroup=true,party=true}
-- GENDER.IDS: SUMMONED, ILLUSIONARY, SUMMONED_DEMON.
M.SUMMONED=removal.SUMMONED
-- Lasting areas: the seconds an enemy takes to start walking out of a fresh cloud, and the chance
-- it stays before the group has seen it in one, worth this many sightings.
M.react=1
M.stayPrior=0.25
M.stayWeight=4
-- The round (Christopher, 2026-10-25: the engine owns it all, and what is quick does not take it):
-- casts, drinks and openers wait for the casting aura (frame.self.aura, seconds until it frees),
-- and one chosen this many seconds or less before it frees is queued and starts when it frees. A
-- weapon attack lasts a round. A creature with nothing worth doing waits this many seconds before
-- it decides again.
M.ROUND=threat.ROUND
M.auraLead=0.5
M.idle=1
-- Seconds of the attack's round a drink takes before the attack after it (see the top): in lab
-- batch J the fighters' potions started at once and their attacks were chosen 0.6 and 1 second
-- after.
M.drinkSeconds=1
-- Interrupting (see the top): a casting aura counts from 0 at a cast's start to about 99, a tick at
-- a time (adapters/eeex/choice.lua reads it); a count up to castSlack seconds past the casting time
-- is still the cast's own.
M.auraTicks=100
M.ticksPerSecond=15
M.castSlack=0.4
-- A jump into the fight lands this far short of its enemy, within a weapon's reach (threat.reach).
M.landShort=48
-- Kiting (see the top): a step of this many seconds away from melee enemies within kiteRange (in
-- range units), none within kiteGap seconds of the creature's last (SCS's retreat.ssl: 60 ticks,
-- Range 6, its runonce timer of 18).
M.kiteSeconds=4
M.kiteRange=6
M.kiteGap=18
-- Positioning (see the top): the shares of the way toward the cast's spot tried, longest first, and
-- the shortest walk worth making (world units: a cell of the game's search map).
M.positionSteps={1,0.75,0.5,0.25}
M.positionMin=16
-- Share of an attack's worth on a petrified statue (sense.statueSource, CBMP1ST): enemies fight
-- active companions first and smash a statue only at low priority or when nothing better stands.
M.statueShare=0.2

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end
-- Whether the adapter found no open way for a move of this kind lately (input.blocked: kite and
-- position true, flank a table of the enemies behind whom it found none).
local function blocked(input,kind,id)
    local b=type(input.blocked)=='table' and input.blocked[kind] or nil
    if kind=='flank' then return type(b)=='table' and b[id]==true end
    return b==true
end
local function reaches(role) return type(role)=='table' and type(role.who)=='table' and (role.who.target or role.who.area) end
local function benefits(role)
    return type(role)=='table' and type(role.who)=='table' and (role.who.target or role.who.area or role.who.point or role.who.party)
end

-- Spell slots (Christopher, 2026-10-21: a slot costs less when the caster has more spells left
-- than rounds it can expect to live, "ja, auf jeden Fall"): the share of a slot's cost that
-- counts now, the rounds the caster lives under the threat it sees, with what protects it now
-- (combat-intent/defence.lua), over the copies it has ready of spells that do something in a
-- fight; 1 while it has the rounds for all of them. Every spell's cost counts the share
-- (input.slots), an item's does not.
function M.slotShare(input)
    local left=0
    for _,row in ipairs(type(input.spells)=='table' and input.spells or {}) do
        if type(row)=='table' and number(row.ready) and row.ready>0 and row.usable and type(row.spell)=='table' and
            type(row.spell.roles)=='table' and next(row.spell.roles)~=nil then left=left+row.ready end
    end
    if left<=1 then return 1 end
    local caster=input.frame.self
    local t=threat.picture(input.frame)[caster.id]
    if not t then return 1 end
    local _,rounds=defence.course(defence.held(caster),caster,t,1)
    if type(rounds)~='number' or rounds~=rounds then return 1 end
    return clamp(math.max(1,rounds)/left,0,1)
end
local function slots(input) return number(input.slots) and input.slots or 1 end

-- 'damage', 'disable' or 'debuff' and how the spell is aimed, or nil and why the engine leaves it
-- out.
function M.attack(spell)
    if type(spell)~='table' or type(spell.roles)~='table' then return nil,'unclassified' end
    if spell.partial then return nil,'partial' end
    local roles=targeting.kindRoles(spell)
    local attacks=reaches(roles.disable) or reaches(roles.damage) or reaches(roles.debuff)
    for _,name in ipairs(OTHER) do
        if benefits(spell.roles[name]) and not (name=='removal' and attacks) then return nil,'role-'..name end
    end
    for _,name in ipairs({'damage','disable','debuff'}) do
        local r=spell.roles[name]
        if type(r)=='table' and type(r.who)=='table' then
            for who in pairs(r.who) do if GLOBAL[who] then return nil,'global' end end
            if r.who.self then return nil,'self-harm' end
        end
    end
    if type(spell.roles.disable)=='table' and spell.roles.disable.kinds and spell.roles.disable.kinds.timestop then
        return nil,'time-stop'
    end
    local kind=reaches(roles.disable) and 'disable' or reaches(roles.damage) and 'damage' or
        reaches(roles.debuff) and 'debuff' or nil
    if not kind then return nil,'no-attack' end
    local a=spell.area
    if spell.projectileUnknown and not targeting.builtinSingle[spell.projectile] then return nil,'unknown-projectile' end
    if a and a.filter=='allies' then return nil,'allies-area' end
    if a and (a.line or a.rectangle) and a.filter~='enemies' then return nil,'unknown-shape' end
    if a and a.cone and not (number(a.cone) and a.cone>0 and a.cone<360) then return nil,'unknown-cone' end
    if a and not (number(a.radius) and a.radius>0) then return nil,'unknown-radius' end
    if spell.target=='creature' then return kind,a and 'creature-area' or 'creature' end
    if spell.target=='point' and a then return kind,'point-area' end
    if spell.target=='self' and a then return kind,'self-area' end
    return nil,'not-aimed'
end

local function range(spell) return number(spell.range) and spell.range*M.rangeUnit or 0 end
-- Seconds the caster walks before it can cast spell at p (a creature or a point): none in range,
-- else the walk into range, as the game's spell actions walk there first (lab batch G3); nil for a
-- cone, which starts where the caster stands, a release (ForceSpellRES goes off where the caster
-- stands, D2b) and a caster that cannot walk.
local function approach(caster,p,spell)
    if targeting.distance(caster,p)<=range(spell) then return 0 end
    if spell.release or (type(spell.area)=='table' and spell.area.cone) then return nil end
    return weapons.approach(caster,p,range(spell))
end
-- The caster where it casts spell at p from: where it stands in range, else where its walk ends,
-- at the spell's range from p on the way.
local function castFrom(caster,p,spell)
    local d,far=targeting.distance(caster,p),range(spell)
    if d<=far or d==math.huge then return caster end
    local at={}
    for k,v in pairs(caster) do at[k]=v end
    at.x,at.y=p.x+(caster.x-p.x)*far/d,p.y+(caster.y-p.y)*far/d
    return at
end

-- Whether e can be aimed at directly: alive, no sanctuary, seen, in range or a walk away from it;
-- the seconds of the walk come third.
local function aimable(caster,e,spell)
    if not targeting.alive(e) then return false,'dead' end
    if number(e.sanctuary) and e.sanctuary>0 then return false,'sanctuary' end
    if targeting.has(e.state,UNSEEN) and not caster.seeInvisible then return false,'invisible' end
    if targeting.distance(caster,e)==math.huge then return false,'no-position' end
    local walk=approach(caster,e,spell)
    if not walk then return false,'out-of-range' end
    return true,nil,walk
end
-- What the spell does to e, or nil and why it does not work on e: its roles for e's kind of
-- creature (spells.view) must hold the attack or a debuff, and e's spell protections must not stop
-- it. A lasting area gets through once the turnings, deflections and traps that count down are
-- spent.
local function affects(spell,e,kind,lasting,input)
    local effective,target=spell,e
    if input and reaches(spell.roles.removal) then effective,target=removal.against(input,spell,e) end
    local roles,key=spells.view(effective,targeting.holds(e))
    if type(roles)~='table' or not (reaches(roles[kind]) or reaches(roles.debuff)) then
        return nil,type(key)=='string' and key:find('?',1,true) and 'unknown-filter' or 'filter'
    end
    if lasting then
        if targeting.stopped(target,effective)==math.huge then return nil,'protected' end
    elseif targeting.protected(target,effective) then return nil,'protected' end
    return roles
end

local resisted=harm.resisted
-- The chance e makes its saving throw against role (targeting.saveChance), and the share of casts
-- its magic resistance lets through (targeting.landing).
M.saveChance=targeting.saveChance
local landing=targeting.landing
-- How long a condition holds on e when e gets a save every few seconds to break free
-- (combat-intent/harm.lua).
M.brokenFree=harm.brokenFree
-- How much of a remembered failure still counts: a spell that missed e without a save and
-- without magic resistance to blame met an immunity.
local function remembered(input,resref,e,role)
    if not input.mind.memory or type(input.memory)~='table' then return 1 end
    local misses=input.memory[resref..':'..tostring(e.id)]
    if not number(misses) or misses<=0 then return 1 end
    local saves=type(role.save)=='table' and next(role.save)~=nil
    if not saves and not (number(e.mr) and e.mr>0) then return 0 end
    if misses>=3 then return 0 end
    return 0.5^misses
end

-- The worth of a damage role landing n times on e (once by default; combat-intent/harm.lua: by the
-- dice), more on the group's focus and on an enemy the creature's orders name, and the hit points
-- it is expected to take. floor: the hit points e keeps at least (targeting.floor).
local function damageOn(input,row,role,e,floor,n)
    local worth,expected=harm.damage(role,e,input.mind.killBonus,floor,n)
    if expected<=0 then return 0,0 end
    if e.statue==true then worth=worth*M.statueShare end
    local plan=input.plan
    if type(plan)=='table' and plan.focus==e.id then worth=worth*(1+input.mind.focusBonus*input.mind.coordination) end
    worth=worth*orders.favour(input,e)
    local still=remembered(input,row.resref,e,role)
    return worth*still,expected*still
end

-- Whether e is the last foe in play: no other living enemy in the group's picture (the director's
-- plan.inPlay, which leaves out the foes out of play, charmed or in a maze) or in the caster's frame.
-- A copy of e (an opening's weakened e) is still e.
local function lastInPlay(input,e)
    local plan=input.plan
    if type(plan)=='table' and type(plan.inPlay)=='table' then
        for key in pairs(plan.inPlay) do if key~=e.id then return false end end
    end
    for _,o in ipairs(input.frame.enemies) do
        local same=o==e or (e.id~=nil and type(o)=='table' and o.id==e.id)
        if not same and targeting.alive(o) then return false end
    end
    return true
end
-- The worth of a disable role on e (combat-intent/harm.lua), more on an enemy the creature's orders
-- name: none on an enemy another member has claimed for its disable, no charm or maze on the last
-- foe in play (harm.UNTOUCHED). floor as for damageOn.
local function disableOn(input,row,role,e,floor)
    if targeting.disabled(e) then return 0 end
    local plan=input.plan
    local reserved=type(plan)=='table' and type(plan.reserved)=='table' and plan.reserved[e.id]
    if reserved and reserved~=input.frame.self.id and input.mind.coordination>=0.5 then return 0 end
    return harm.disable(role,e,input.mind.killBonus,floor,lastInPlay(input,e))*remembered(input,row.resref,e,role)*
        orders.favour(input,e)
end

local function offset(a,b) return b.x-a.x,(b.y-a.y)*4/3 end
local function inCone(origin,aim,p,radius,half)
    local ax,ay=offset(origin,aim)
    local px,py=offset(origin,p)
    local d=math.sqrt(px*px+py*py)
    if d>radius then return false end
    if d<1 then return true end
    local la=math.sqrt(ax*ax+ay*ay)
    if la<1 then return false end
    return (ax*px+ay*py)/(la*d)>=math.cos(math.rad(math.min(half,180)))
end

-- Who an area at center (aimed at aim for a cone) reaches, by edge: inside returns whether p
-- is in it, near whether p is within the ally margin of it.
local function shape(spell,caster,center,aim)
    local a=spell.area
    if a.cone then
        local half=a.cone/2
        return function(p) return inCone(caster,aim,p,a.radius,half) end,
            function(p) return inCone(caster,aim,p,a.radius+M.allyMargin,half+10) end
    end
    return function(p) return targeting.distance(center,p)<=a.radius end,
        function(p) return targeting.distance(center,p)<=a.radius+M.allyMargin end
end

-- What an attack's removal (combat-intent/removal.lua) adds on e, over the rounds left after the
-- cast: below zero when it frees e of more than it opens.
local function stripped(input,spell,e)
    if not reaches(spell.roles.removal) then return 0 end
    local horizon=number(input.mind.horizon) and input.mind.horizon or 18
    local cast=(number(spell.speed) and spell.speed or 0)*removal.speedSeconds
    return (removal.on(input,spell,e,math.max(0,horizon-cast)/removal.ROUND))
end

-- Lasting areas (see the top). Whether the spell's area is one the profile counts by its
-- explosions.
local function lastingArea(input,spell)
    local a=spell.area
    return input.mind.clouds~='once' and type(a)=='table' and number(a.explosions) and a.explosions>1 and
        number(a.every) and a.every>0 or false
end
-- The hits of a schedule (the first at first seconds after the landing, then one every step up
-- to the last explosion) during [from, to].
local function hitsIn(first,step,last,from,to)
    to=math.min(to,last)
    if to<from then return 0 end
    local lo=math.max(0,math.ceil((from-first)/step-1e-9))
    local hi=math.floor((to-first)/step+1e-9)
    return math.max(0,hi-lo+1)
end
-- Whether e cannot walk out of a cloud (zones.rooted), unless it only sleeps and the cloud's
-- damage wakes it.
local SLEEP=targeting.STATE.sleeping
local function stuck(e,damages)
    if not zones.rooted(e) then return false end
    if damages and e.rooted~=true and not (number(e.held) and e.held>0) and targeting.has(e.state,SLEEP) and
        not targeting.has(e.state,targeting.DISABLED-SLEEP) then return false end
    return true
end
-- The chance e stays in a cloud that hurts it: what the group has seen, after the prior.
local function stayChance(input,e)
    local s=type(input.stays)=='table' and input.stays[e.id] or nil
    local stay=type(s)=='table' and number(s.stay) and s.stay>0 and s.stay or 0
    local left=type(s)=='table' and number(s.left) and s.left>0 and s.left or 0
    return (M.stayPrior*M.stayWeight+stay)/(M.stayWeight+stay+left)
end
-- The share of casts of role that land on e and hold: magic resistance, the saving throw and the
-- effect's own chance.
local function sticks(role,e)
    return landing(role,e)*(1-M.saveChance(role,e))*clamp(number(role.chance) and role.chance or 1,0,1)
end
-- What a worth that counts role landing once on e becomes over n tries (one for a cast): as likely
-- as it lands at least once.
local function tries(role,e,n)
    local c=math.min(1,sticks(role,e))
    if c<=0 then return 0 end
    return (1-(1-c)^n)/c
end

-- The armour class the enemies' weapons meet: the mean of the caster's side (threat.armour), once
-- a choice (ctx).
local function facing(input,ctx)
    if ctx and ctx.armour~=nil then return ctx.armour or nil end
    local ac=threat.armour(threat.friends(input.frame))
    if ctx then ctx.armour=ac or false end
    return ac
end
-- Whether a debuff role lowers an enemy's defences for the attacks after it (harm.weakened): its
-- saving throws, magic resistance, resistances or armour class, or blindness.
local function opens(role)
    if type(role)~='table' then return false end
    local a=type(role.amounts)=='table' and role.amounts or {}
    return (type(role.saveBy)=='table' and next(role.saveBy)~=nil) or
        (type(role.resist)=='table' and next(role.resist)~=nil) or (number(a.armor) and a.armor>0) or
        (number(a.magicResistance) and a.magicResistance>0) or (type(role.mrCuts)=='table' and #role.mrCuts>0) or
        (type(role.kinds)=='table' and role.kinds.blind==true) or false
end
local worthOn
-- Openings (see the top): what a debuff role that lowers e's defences opens for the attacks after
-- it, as likely as it lands. The most one of the caster's other ready attack spells gains on e
-- weakened (harm.weakened) over e as it is, when the debuff lasts into the next round; and what
-- the weapons of the caster's allies gain on e's worse armour class and resistances over the
-- rounds it holds within the horizon (allies within a weapon's reach of e, and those with missiles
-- when e is the group's focus), no more than e has left. Nothing when the creature does not see it
-- (M.tactical). ctx keeps it for one choice.
local function opening(input,row,role,e,ctx)
    if not opens(role) or not M.tactical(input) then return 0 end
    local key=tostring(row.resref)..':'..tostring(e.id)
    if ctx and ctx.openings and ctx.openings[key] then return ctx.openings[key] end
    local w=harm.weakened(role,e)
    local gain=0
    if w then
        local horizon=number(input.mind.horizon) and input.mind.horizon or 18
        local span=role.duration=='permanent' and horizon or
            number(role.duration) and math.min(role.duration,horizon) or horizon/2
        if span>=M.ROUND then
            for _,other in ipairs(type(input.spells)=='table' and input.spells or {}) do
                if type(other)=='table' and other~=row and other.resref~=row.resref and number(other.ready) and other.ready>0 and
                    other.usable then
                    local kind=M.attack(other.spell)
                    local roles=kind and affects(other.spell,e,kind,nil,input)
                    if roles then
                        gain=math.max(gain,worthOn(input,other,kind,roles,w,ctx,true)-worthOn(input,other,kind,roles,e,ctx,true))
                    end
                end
            end
        end
        local hp,maxHp=e.hp,e.maxHp
        if number(hp) and number(maxHp) and maxHp>0 and hp>0 then
            local plan=input.plan
            local focus=type(plan)=='table' and plan.focus==e.id
            local more=0
            for _,f in ipairs(type(input.frame.allies)=='table' and input.frame.allies or {}) do
                if type(f)=='table' and type(f.attack)=='table' and targeting.alive(f) and not targeting.disabled(f) then
                    local a=threat.attack(f)
                    if (a.ranged and focus) or (not a.ranged and targeting.distance(f,e)<=threat.reach) then
                        local label=weapons.DAMAGE[a.damageType] or ''
                        more=more+a.apr*a.damage*(threat.hitChance(a.thac0,w.ac)*resisted(w,label)-
                            threat.hitChance(a.thac0,e.ac)*resisted(e,label))
                    end
                end
            end
            gain=gain+math.min(math.max(0,more)*span/M.ROUND,hp)/maxHp
        end
        gain=gain*harm.chance(role,e)
    end
    if ctx then ctx.openings=ctx.openings or {};ctx.openings[key]=gain end
    return gain
end
-- The worth of a debuff role on e (combat-intent/harm.lua) against the armour class of the
-- caster's side, more on an enemy the creature's orders name, with what it opens unless plain:
-- none on an enemy that carries the spell's effects already (harm.carries), nor on one another
-- member casts the same spell at (the director's plan, cursed).
local function debuffOn(input,row,role,e,ctx,plain)
    if harm.carries(e,row.spell,row.resref) then return 0 end
    local plan=input.plan
    local cursed=type(plan)=='table' and type(plan.cursed)=='table' and plan.cursed[e.id]
    local owner=type(cursed)=='table' and cursed[row.resref]
    if owner and owner~=input.frame.self.id and input.mind.coordination>=0.5 then return 0 end
    local worth=harm.debuff(role,e,facing(input,ctx),input.tables)
    if not plain then worth=worth+opening(input,row,role,e,ctx) end
    return worth*remembered(input,row.resref,e,role)*orders.favour(input,e)
end
-- Teleport Field (harm.teleport; Christopher, 2026-11-03): the friend e fights in melee, the caster or
-- an ally its action aims at, when e's weapon is no ranged one; nil when it fights none of them so.
local function fighting(input,e)
    local id=e.actee
    if not number(id) or id<0 or threat.attack(e).ranged then return nil end
    local frame=input.frame
    if type(frame.self)=='table' and frame.self.id==id then return frame.self end
    for _,f in ipairs(type(frame.allies)=='table' and frame.allies or {}) do
        if type(f)=='table' and f.id==id and targeting.alive(f) then return f end
    end
end
local function teleports(role) return type(role)=='table' and type(role.kinds)=='table' and role.kinds.teleportField==true end
-- What n explosions of a Teleport Field take from e's fight while it fights a friend in melee, as
-- debuffOn weighs a debuff: nothing on an enemy another member casts the same spell at, more on one
-- the creature's orders name.
local function teleportOn(input,row,role,e,n)
    if not fighting(input,e) then return 0 end
    local plan=input.plan
    local cursed=type(plan)=='table' and type(plan.cursed)=='table' and plan.cursed[e.id]
    local owner=type(cursed)=='table' and cursed[row.resref]
    if owner and owner~=input.frame.self.id and input.mind.coordination>=0.5 then return 0 end
    return harm.teleport(role,e,n)*remembered(input,row.resref,e,role)*orders.favour(input,e)
end
-- The worth on e of the spell's kind of attack and the debuff beside it over n explosions (one
-- for a cast), and the hit points it is expected to take: damage n times over, added up by the
-- dice (e dies once, however many explosions it takes); a disable or a debuff as likely as it
-- lands at least once; a debuff beside damage in full, beside a disable as likely as the disable
-- never lands. Only what e's roles hold counts: an enemy only the debuff reaches gets the debuff
-- alone. plain: without openings.
local function attackOn(input,row,kind,roles,e,ctx,n,plain)
    local floor=targeting.floor(e,roles)
    local worth,hp=0,0
    local main=roles[kind]
    if reaches(main) then
        if kind=='damage' then worth,hp=damageOn(input,row,main,e,floor,n)
        elseif kind=='disable' then worth=disableOn(input,row,main,e,floor)*tries(main,e,n)
        elseif teleports(main) then worth=teleportOn(input,row,main,e,n)
        else worth=debuffOn(input,row,main,e,ctx,plain)*tries(main,e,n) end
    end
    if kind~='debuff' and reaches(roles.debuff) then
        local d=debuffOn(input,row,roles.debuff,e,ctx,plain)*tries(roles.debuff,e,n)
        if kind=='disable' and reaches(main) and harm.within(main,e) then d=d*(1-math.min(1,sticks(main,e)))^n end
        worth=worth+d
    end
    return worth,hp
end
-- The worth of the spell's kind of attack on e with the debuff beside it, and for damage the hit
-- points it is expected to take.
worthOn=function(input,row,kind,roles,e,ctx,plain) return attackOn(input,row,kind,roles,e,ctx,1,plain) end
-- What a lasting area is worth on e inside it at center: the worth of its kind of attack over the
-- explosions e is expected to sit through, the hit points it is expected to take, and for the log
-- how many it would sit through staying and walking out and the chance it stays. ctx keeps the
-- rest of the fight for one choice; walk: the seconds the caster walks into range first.
local function lastingOn(input,row,spell,kind,roles,e,center,ctx,walk)
    local a=spell.area
    local caster=input.frame.self
    local every=a.every
    local step=every*math.max(1,math.ceil(zones.period({every=every,spell=spell})/every-1e-9))
    local first=a.skipFirst and every or 0
    local last=first+(a.explosions-1)*every
    ctx.rest=ctx.rest or threat.rest(type(input.fight)=='table' and input.fight or input.frame,
        number(input.mind.fightCap) and input.mind.fightCap or 60)
    local cast=(number(spell.speed) and spell.speed or 0)*zones.speedSeconds+(number(caster.aura) and caster.aura>0 and caster.aura or 0)+
        (number(walk) and walk>0 and walk or 0)
    -- A foe out of play (readiness, see the top) is in the area from when it is likely back on,
    -- for the rest of the fight from then.
    local back=number(input.calm) and number(e.back) and math.max(0,e.back) or 0
    local from=math.max(0,back-cast)
    local upto=back>0 and back+ctx.rest-cast or math.max(first,ctx.rest-cast)
    local stay=hitsIn(first,step,last,from,upto)
    -- A Teleport Field: a foe that fights a friend in melee comes back for each explosion while that
    -- friend stands in the field, and gets one otherwise; walking out costs it that fight all the same.
    if kind=='debuff' and teleports(roles.debuff) then
        local friend=fighting(input,e)
        local n=stay
        if friend and targeting.distance(center,friend)>a.radius then n=math.min(n,1) end
        n=math.max(0,n-targeting.stopped(e,spell))
        return teleportOn(input,row,roles.debuff,e,n),0,{id=e.id,stay=n,leave=n,q=1}
    end
    local leave,walk=stay,0
    if not stuck(e,reaches(roles.damage)) then
        local speed=number(e.speed) and e.speed>0 and e.speed or zones.walkSpeed
        walk=math.max(0,a.radius-targeting.distance(a.cone and caster or center,e)+zones.margin)/speed
        leave=hitsIn(first,step,last,from,math.min(upto,from+M.react+walk))
    end
    local stopped=targeting.stopped(e,spell)
    local function over(n)
        n=n-stopped
        if n<=0 then return 0,0 end
        return attackOn(input,row,kind,roles,e,ctx,n)
    end
    local ws,hs=over(stay)
    local wl,hl=over(leave)
    if walk>0 then wl=wl+walk/M.fullSeconds*(0.5+0.5*targeting.health(e)) end
    local q=input.mind.clouds=='best' and 0 or stayChance(input,e)
    local wb,hb=ws,hs
    if wl<ws then wb,hb=wl,hl end
    return q*ws+(1-q)*wb,q*hs+(1-q)*hb,{id=e.id,stay=stay,leave=leave,q=q,stopped=stopped>0 and stopped or nil}
end
-- Whether an area of the caster's own does nothing to friend f in it (the caster or an ally): its
-- spell protections stop every explosion, or the spell's roles for f's kind of creature, judged
-- on all their conditions, hold no damage, disable or condition that gets through (zones.hit
-- weighs it as it would a zone around f).
local function spared(input,spell,f)
    if type(f)~='table' then return false end
    local worth,first=zones.hit(input,{spell=spell,side='friend',filter=spell.area.filter},f)
    if first>=(number(spell.area.explosions) and spell.area.explosions or 1) then return true end
    local _,key=spells.view(spell,targeting.holds(f))
    if type(key)~='string' or key:find('?',1,true) then return false end
    return worth<=0
end

-- Interrupting (see the top). When the cast c of an enemy (e.cast: its speed, and timer, the count
-- of its casting aura, -1 while the aura is free) can be broken, in seconds from now: from start
-- until finish; nil when its casting is over, instant or unknown. A count past the casting time is
-- the last cast's aura, which the cast waits for: it begins casting when the aura frees. With the
-- aura free the cast has not begun (it may still walk into range): all its casting is ahead.
function M.castWindow(c)
    if type(c)~='table' or not number(c.speed) or c.speed<=0 then return nil end
    local casting=c.speed*zones.speedSeconds
    local timer=number(c.timer) and c.timer or -1
    if timer<0 then return 0,casting end
    local since=timer/M.ticksPerSecond
    if since<=casting+M.castSlack then
        if since>=casting then return nil end
        return 0,casting-since
    end
    local start=math.max(0,(M.auraTicks-timer)/M.ticksPerSecond)
    return start,start+casting
end
-- Whether the creature sees the chance a tactic needs wit for in this decision: input.tactical once
-- the decision has drawn it (M.notices), else whether its chance (mind.tactics) is a half or more.
function M.tactical(input)
    if input.tactical~=nil then return input.tactical==true end
    local p=number(input.mind.tactics) and input.mind.tactics or 1
    return p>=0.5
end
-- Whether a jump into the fight is there to notice (M.jumpOptions): the creature walks to enemies
-- for its melee weapon, has a teleport ready and sees an enemy a jump's walk away.
local function leaping(input)
    if type(input.teleports)~='table' or #input.teleports==0 or input.mind.chase~=true then return false end
    local caster=input.frame.self
    if type(caster.weapon)~='table' or caster.weapon.ranged then return false end
    for _,e in ipairs(input.frame.enemies) do
        local d=type(e)=='table' and targeting.distance(caster,e) or math.huge
        if d<math.huge and d-M.landShort>=search.jumpMin then return true end
    end
    return false
end
-- The weapons the caster can attack with (F2c): the one in its hand first, then the others it
-- could take up (frame.self.arsenal, combat-intent/arsenal.lua), each with its damage known; none
-- but the one in hand while a magic weapon is there (frame.self.magicItem), as the game keeps it.
function M.arsenal(caster)
    local list={}
    if type(caster.weapon)=='table' and number(caster.weapon.damage) then list[1]=caster.weapon end
    if caster.magicItem then return list end
    for _,w in ipairs(type(caster.arsenal)=='table' and caster.arsenal or {}) do
        if type(w)=='table' and number(w.damage) then list[#list+1]=w end
    end
    return list
end
-- Whether the caster carries a missile weapon (M.arsenal) it could shoot an enemy with: one alive
-- and seen, without sanctuary, in its range or a walk away, not immune to the weapon and not
-- keeping its missiles off. body: only a weapon that is part of the creature (arms.body).
local function shooting(input,body)
    local caster=input.frame.self
    for _,arms in ipairs(M.arsenal(caster)) do
        if arms.ranged and (not body or arms.body) then
            for _,e in ipairs(input.frame.enemies) do
                local ok,why=weapons.reachable(caster,e,input.mind,arms)
                if (ok or why=='out-of-reach') and not weapons.immuneTo(e,arms) and not weapons.missileBlocked(e,arms) then
                    return true
                end
            end
        end
    end
    return false
end
-- The melee enemies within kiteRange of the caster that can fight: those a step away is from.
local function pressing(input)
    local caster=input.frame.self
    local out={}
    for _,o in ipairs(input.frame.enemies) do
        if type(o)=='table' and targeting.alive(o) and not targeting.disabled(o) and not threat.attack(o).ranged and
            targeting.distance(caster,o)<=M.kiteRange*M.rangeUnit then out[#out+1]=o end
    end
    return out
end
-- Whether the caster has a spell ready to cast (a casting kind of creature, for kiting).
local function spelling(input)
    for _,row in ipairs(type(input.spells)=='table' and input.spells or {}) do
        if type(row)=='table' and number(row.ready) and row.ready>0 and row.usable and type(row.spell)=='table' then return true end
    end
    return false
end
-- Whether kiting is there to notice (M.kite): a melee enemy stands close and the caster has a
-- missile weapon to shoot with or a spell ready.
local function kiting(input)
    return input.mind.weapons==true and #pressing(input)>0 and (shooting(input) or spelling(input))
end
-- Whether damage can break option o as it is cast: a spell or ability with a casting time, cast
-- where the caster stands; not a potion or other item, a weapon, a strike, a walk or a release
-- (SCS's sequencers and triggers go off by ForceSpellRES, which nothing breaks).
local function breakable(o)
    return type(o)=='table' and number(o.speed) and o.speed>0 and not o.use and not o.item and not o.release and
        o.kind~='weapon' and o.kind~='strike' and number(o.score) and o.score>0
end
-- The melee hits expected to land on the caster during a cast of cast seconds that begins start
-- seconds from now at spot: a melee enemy within reach of spot hits from the beginning; one whose
-- action aims at the caster walks to it from where it stands, late seconds late (when the caster
-- steps away, M.react), at its own speed; the others stay where they are. Less the hits its Mirror
-- Images and Stoneskin skins take first.
local function meleeHits(input,spot,start,cast,late)
    local frame=input.frame
    local caster=frame.self
    local n=0
    for _,o in ipairs(frame.enemies) do
        if type(o)=='table' and targeting.alive(o) and not targeting.disabled(o) then
            local a=threat.attack(o)
            local d=targeting.distance(o,spot)
            local at
            if a.ranged or d==math.huge then at=nil
            elseif d<=threat.reach then at=0
            elseif o.actee==caster.id then at=late+(d-threat.reach)/weapons.speed(o) end
            if at then
                n=n+a.apr*threat.hitChance(a.thac0,caster.ac)*math.max(0,start+cast-math.max(start,at))/M.ROUND
            end
        end
    end
    local absorbed=(number(caster.mirror) and caster.mirror>0 and caster.mirror or 0)+
        (number(caster.skins) and caster.skins>0 and caster.skins or 0)
    return math.max(0,n-absorbed)
end
-- Whether a backstab is there to notice (M.flankOptions, M.hideOpening): the caster can backstab
-- with a weapon it carries and sees an enemy it could stab, and it is hidden (going behind) or not
-- (hiding first).
local function stabbing(input)
    local caster=input.frame.self
    if input.mind.weapons~=true then return false end
    local able=false
    for _,arms in ipairs(M.arsenal(caster)) do if backstab.able(caster,arms) then able=true;break end end
    if not able then return false end
    for _,e in ipairs(input.frame.enemies) do if backstab.open(e) then return true end end
    return false
end
-- Whether an opening is there to notice: a ready attack spell's debuff lowers an enemy's defences.
local function opener(input)
    for _,row in ipairs(type(input.spells)=='table' and input.spells or {}) do
        if type(row)=='table' and number(row.ready) and row.ready>0 and row.usable and type(row.spell)=='table' and
            type(row.spell.roles)=='table' and opens(row.spell.roles.debuff) and M.attack(row.spell) then return true end
    end
    return false
end
-- Whether freeing is there to notice (combat-intent/removal.lua): an enemy in the charmed state, one
-- the other side charmed, and a ready removal spell.
local function freeing(input)
    local charmed=false
    for _,e in ipairs(input.frame.enemies) do
        if type(e)=='table' and targeting.alive(e) and targeting.charmed(e) then charmed=true;break end
    end
    if not charmed then return false end
    for _,row in ipairs(type(input.spells)=='table' and input.spells or {}) do
        if type(row)=='table' and number(row.ready) and row.ready>0 and row.usable and removal.removal(row.spell) then
            return true
        end
    end
    return false
end
-- Whether positioning is there to notice (M.position): the casting aura runs, the caster can walk,
-- and an enemy or ally it sees stands beyond the range of one of its ready spells cast at a creature
-- or a point.
local function positioning(input)
    local frame=input.frame
    local caster=frame.self
    if not (number(caster.aura) and caster.aura>M.auraLead) or caster.rooted==true then return false end
    local shortest=math.huge
    for _,row in ipairs(type(input.spells)=='table' and input.spells or {}) do
        if type(row)=='table' and number(row.ready) and row.ready>0 and row.usable and type(row.spell)=='table' and
            (row.spell.target=='creature' or row.spell.target=='point') then shortest=math.min(shortest,range(row.spell)) end
    end
    if shortest==math.huge then return false end
    for _,list in ipairs({frame.enemies,type(frame.allies)=='table' and frame.allies or {}}) do
        for _,c in ipairs(list) do
            local d=type(c)=='table' and targeting.distance(caster,c) or math.huge
            if d<math.huge and d>shortest then return true end
        end
    end
    return false
end
-- Draws once a decision whether the creature sees a tactic's chance (mind.tactics), and only when
-- there is one to see (an enemy casts, a jump into the fight is there, a debuff opens an enemy's
-- defences, a melee enemy close by can be stepped away from, a backstab is there, a walk into
-- position in the casting pause, an enemy the other side charmed to free, or a removal screen), so that other
-- decisions draw nothing. Without input.rng: when its chance is a half or more.
function M.notices(input)
    local p=number(input.mind.tactics) and input.mind.tactics or 1
    if p>=1 then return true end
    if p<=0 then return false end
    local any=false
    for _,e in ipairs(input.frame.enemies) do
        if type(e)=='table' and type(e.cast)=='table' then any=true;break end
    end
    if not any and not leaping(input) and not opener(input) and not kiting(input) and not stabbing(input) and
        not positioning(input) and not freeing(input) and not removal.screening(input) then return false end
    local rng=input.rng
    if not rng then return p>=0.5 end
    return rng:nextInt(1,1000)<=math.floor(p*1000+0.5)
end
-- What breaking e's spell is worth to an attack whose damage lands how.at seconds from now with
-- chance how.chance, or whose hits come how.rate a round from how.from seconds on, less how.absorbed
-- hits that Mirror Images and Stoneskin take first: mind.interrupt for each level of the spell, times
-- the chance damage lands while the casting runs. Nothing when the creature does not see the chance
-- (M.tactical).
function M.interruption(input,e,how)
    local c=type(e)=='table' and e.cast or nil
    local per=number(input.mind.interrupt) and input.mind.interrupt or 0
    if type(c)~='table' or per<=0 or not number(c.level) or c.level<=0 or not M.tactical(input) then return 0 end
    local start,finish=M.castWindow(c)
    if not start then return 0 end
    local p
    if number(how.rate) then
        local from=math.max(number(how.from) and how.from or 0,start)
        local span=math.min(finish,from+M.ROUND)-from
        if span<=0 then return 0 end
        local n=how.rate*span/M.ROUND-(number(how.absorbed) and how.absorbed or 0)
        if n<=0 then return 0 end
        p=1-math.exp(-n)
    else
        if not number(how.at) or how.at<start or how.at>=finish then return 0 end
        p=clamp(number(how.chance) and how.chance or 0,0,1)
    end
    return per*c.level*p
end
-- The chance a damage role hurts e at all: magic resistance, a saving throw that keeps all of it off
-- (one for half still hurts) and the effect's own chance.
local function hurts(role,e)
    local save=role.saveForHalf and 0 or M.saveChance(role,e)
    return landing(role,e)*(1-save)*clamp(number(role.chance) and role.chance or 1,0,1)
end

-- One option: the spell aimed at a creature or a point, its worth, cost and score, or nil
-- and why it is no option. ctx keeps what one choice works out once (the rest of the fight). An
-- aim with a walk into range must keep the caster out of its area where the walk ends, and the
-- walk comes first and lowers the worth as a walk to a melee enemy does (weapons.paced). Damage on
-- a casting enemy adds what breaking its spell is worth (interrupt), once the walk has lowered the
-- rest: the damage lands after the casting aura, the walk and the casting, and an area that skips
-- its first explosion a round of explosions later.
local function evaluate(input,row,spell,kind,mode,aim,ctx)
    local frame=input.frame
    local caster=frame.self
    local a=spell.area
    -- Readiness (see the top): before the foes out of play are back only an area laid on a spot
    -- that lasts until then gives anything; no creature out of play can be aimed at.
    local away=number(input.calm)
    if away and ((mode~='point-area' and mode~='self-area') or not lastingArea(input,spell) or a.line or a.rectangle) then
        return nil,'away'
    end
    local worth,hits,slack,expected=0,{},0,{}
    local sat
    local walk=number(aim.walk) and aim.walk>0 and aim.walk or nil
    local stop=0
    local land=(number(caster.aura) and caster.aura>0 and caster.aura or 0)+(walk or 0)+
        (number(spell.speed) and spell.speed or 0)*zones.speedSeconds+
        (type(a)=='table' and a.skipFirst and number(a.every) and a.every or 0)
    local function breaks(roles,e,hp)
        if kind=='damage' and number(hp) and hp>0 then
            stop=stop+M.interruption(input,e,{at=land,chance=hurts(roles.damage,e)})
        end
    end
    if mode=='creature' then
        local e=aim.enemy
        local roles,why=affects(spell,e,kind,nil,input)
        if not roles then return nil,why end
        if kind=='disable' and targeting.disabled(e) then return nil,'disabled' end
        worth,expected[e.id]=worthOn(input,row,kind,roles,e,ctx)
        worth=worth+stripped(input,spell,e)
        breaks(roles,e,expected[e.id])
        hits[1]=e.id
    else
        local center=aim.point
        if a.line or a.rectangle then
            -- An enemies-only line or box: counted for the creature aimed at only.
            local e=aim.enemy
            local roles=e and affects(spell,e,kind,nil,input)
            if not roles then return nil,'shape' end
            worth,expected[e.id]=worthOn(input,row,kind,roles,e,ctx)
            worth=worth+stripped(input,spell,e)
            breaks(roles,e,expected[e.id])
            hits[1]=e.id
        else
            local inside,near=shape(spell,caster,center,aim.point)
            if a.filter~='enemies' then
                for _,ally in ipairs(type(frame.allies)=='table' and frame.allies or {}) do
                    if targeting.alive(ally) and near(ally) and not spared(input,spell,ally) then return nil,'ally-in-area' end
                end
                -- Nor on a foe the caster's side charmed, wherever the caster last saw it: harming it
                -- breaks the charm by the rules text (Christopher, 2026-10-29).
                if away then
                    for _,e in ipairs(frame.enemies) do
                        if e.away=='charm' and targeting.alive(e) and near(e) and not spared(input,spell,e) then
                            return nil,'charmed-in-area'
                        end
                    end
                end
                -- A cone starts at the caster; any other area must keep it out where it casts
                -- from, unless it does nothing to the caster.
                if not a.cone then
                    local at=walk and castFrom(caster,center,spell) or caster
                    local within
                    if mode=='self-area' then within=not a.skipsCenter else within=near(at) end
                    if within and not spared(input,spell,at) then return nil,'caster-in-area' end
                end
            end
            local lasting=lastingArea(input,spell)
            if lasting then sat={} end
            -- How far the nearest hit enemy is from the area's edge: an area that holds its
            -- enemies well inside still hits them after a step.
            slack=math.huge
            for _,e in ipairs(frame.enemies) do
                local roles=targeting.alive(e) and inside(e) and affects(spell,e,kind,lasting,input)
                -- Before they are back, only a mazed foe whose return can be told is in the area:
                -- it comes back where it went; a charmed one walks about meanwhile.
                if roles and away and (e.away~='maze' or not number(e.back)) then roles=nil end
                if roles then
                    local w,hp,seen
                    if lasting then w,hp,seen=lastingOn(input,row,spell,kind,roles,e,center,ctx,walk)
                    else w,hp=worthOn(input,row,kind,roles,e,ctx) end
                    w=w+stripped(input,spell,e)
                    if w>0 then
                        worth=worth+w;hits[#hits+1]=e.id;expected[e.id]=hp
                        breaks(roles,e,hp)
                        if seen then sat[#sat+1]=seen end
                        slack=math.min(slack,a.radius-targeting.distance(a.cone and caster or center,e))
                    end
                end
            end
            if slack==math.huge then slack=0 end
        end
    end
    if worth<=0 then return nil,'no-worth' end
    if walk then worth=worth*weapons.paced(walk) end
    worth=worth+stop
    local level=number(row.level) and row.level or number(spell.level) and spell.level or 1
    local cost=input.mind.economy*slots(input)*M.costPerLevel*level
    local option={resref=row.resref,kind=kind,mode=mode,worth=worth,cost=cost,score=worth-cost,hits=hits,slack=slack,
        speed=number(spell.speed) and spell.speed or 0,release=spell.release or nil,walk=walk,
        interrupt=stop>0 and stop or nil}
    if kind=='damage' then option.expected=expected end
    if sat and #sat>0 then option.lasting=sat end
    if aim.enemy and (mode=='creature' or mode=='creature-area') then option.target=aim.enemy.id
    elseif mode=='point-area' and aim.enemy and not aim.enemy.away and aimable(caster,aim.enemy,spell) then
        -- An area aimed at an enemy's spot goes at that enemy, as SCS casts its areas: the game sets
        -- it off where the enemy stands when the cast goes off, not where it stood when it was chosen
        -- (lab batch E8 v3: Neira's Unholy Blight at the spot of a charging hero, who had walked on by
        -- then). One the caster cannot aim at (sanctuary, unseen) or out of play stays on the spot.
        option.target=aim.enemy.id;option.mode='creature-area'
    elseif mode=='point-area' then option.point={x=math.floor(aim.point.x+0.5),y=math.floor(aim.point.y+0.5)}
    elseif mode=='self-area' then option.self=true
    elseif aim.enemy then option.target=aim.enemy.id end
    return option
end

-- What the hit of touch charge w does to e (the strike's roles for e's kind of creature): the
-- worth of its damage and disable together, and the hit points it is expected to take. A strike
-- that keeps e at one hit point or more (a minimum it puts on e) cannot kill, nor can one while
-- e's own minimum holds.
local function strikeOn(input,row,w,e)
    local roles=spells.view(w.strike,targeting.holds(e))
    if type(roles)~='table' then return 0,0 end
    local own=roles.protection
    local spare=type(own)=='table' and type(own.kinds)=='table' and own.kinds.minimumHp and
        type(own.who)=='table' and own.who.target and true or false
    local floor=math.max(spare and 1 or 0,targeting.floor(e,roles))
    local worth,expected=0,0
    if reaches(roles.damage) then worth,expected=damageOn(input,row,roles.damage,e,floor) end
    if reaches(roles.disable) then worth=worth+disableOn(input,row,roles.disable,e,floor) end
    return worth,expected
end
-- Whether weapons are out for the caster: its own Time Stop or Improved Alacrity.
local function weaponsOut(input)
    return openers.ownStop(input)~=nil or input.frame.self.alacrity==true
end

-- Touch options of one ready spell: cast on the caster, aimed at each enemy in reach the charge
-- would work on. Worth: the hit's worth times the chance to hit, and on a casting enemy what
-- breaking its spell is worth when the strike comes after the casting aura and the casting. Cost:
-- the spell's level, and the caster's hit points lost to the weapons around the target while it
-- strikes, times caution.
local function touchOptions(input,row,spell,w,out,reject)
    local frame=input.frame
    local caster=frame.self
    local mind=input.mind
    local maxHp=number(caster.maxHp) and caster.maxHp>0 and caster.maxHp or nil
    local level=number(row.level) and row.level or number(spell.level) and spell.level or 1
    local ahead=(number(caster.aura) and caster.aura>0 and caster.aura or 0)+
        (number(spell.speed) and spell.speed or 0)*zones.speedSeconds
    for _,e in ipairs(frame.enemies) do
        local ok,why=touch.reachable(caster,e,mind)
        if ok then why=touch.blocked(e,w) end
        if ok and not why then
            local worth,expected=strikeOn(input,row,w,e)
            if worth>0 then
                local p=touch.hitChance(caster,e,w)
                local stop=expected>0 and M.interruption(input,e,{from=ahead,rate=p}) or 0
                local exposure=maxHp and mind.caution*touch.exposure(frame,e)*touch.exposedRounds/maxHp or 0
                local cost=mind.economy*slots(input)*M.costPerLevel*level+exposure
                local value=worth*p+stop
                out[#out+1]={resref=row.resref,kind='touch',mode='self',self=true,target=e.id,worth=value,
                    cost=cost,score=value-cost,hits={e.id},slack=0,hit=p,expected={[e.id]=expected*p},
                    speed=number(spell.speed) and spell.speed or 0,item=w.item,interrupt=stop>0 and stop or nil}
            else reject('no-worth') end
        else reject(why) end
    end
end

-- The worth of hits of weapon arms on e (raw: those expected to land, over one round or more;
-- absorbed, optional: how many of them e's Mirror Images and Stoneskin skins take first), and the
-- hit points e is expected to take. A hit deals the weapon's own damage, which neither magic
-- resistance nor a save lessens, and what it casts or applies, which both do; so do the on-hit
-- effects the caster carries (its guard's hits, F2a: Smite Evil, a poisoned blade) that fit the
-- weapon (weapons.payloads), one the hit takes off again on the first hit alone. No spell
-- protection stops the weapon, one against what its hit casts stops that part. The hits kill
-- when those expected reach those needed, as likely as the last one lands (two swings that each
-- hit four times in five, needing both: 0.6), unless e's minimum holds against them
-- (targeting.floor): then they take what it has above it. The strongest disable and the strongest
-- debuff (F2e) a hit brings count as likelier the more hits that bring them land, the debuff
-- against the armour class of the caster's side and none on an enemy that carries it already
-- (harm.carries). A critical hit effect (F2e) comes with the critical hits among the hits
-- (weapons.critical, by the caster's critical hit points) where no helmet keeps them off
-- (defence.critOpen): what it deals counts as expected, but not toward a kill, which no one plans on
-- a critical hit. bs (combat-intent/backstab.lua, optional): the chance the first hit is a
-- backstab, which multiplies the weapon's own damage of that hit (not what it casts); a kill counts
-- as likely as it is with the backstab and without. Only the hits past the images and skins deal
-- anything, bring a disable or a debuff and kill now; but each one they take brings the kill a hit
-- closer, as the skins and images are gone once taken. So the hits count at least as the progress
-- they make toward the kill: what they would deal with nothing in the way, times the share of real
-- hits among all the hits the kill takes (lab batch J run 3: five skins on the party's last mage
-- took all of a round's two or three hits, and the group waited two minutes in front of her).
local function critPoints(guard)
    local roles=type(guard)=='table' and type(guard.roles)=='table' and guard.roles or {}
    local function points(role)
        local a=type(role)=='table' and role.amounts
        return type(a)=='table' and number(a.critical) and a.critical or 0
    end
    return points(roles.buff)-points(roles.debuff)
end
local function hitsOn(input,arms,raw,e,bs,absorbed)
    local hp,maxHp=e.hp,e.maxHp
    if not number(raw) or raw<=0 or not number(hp) or not number(maxHp) or maxHp<=0 or hp<=0 then return 0,0 end
    absorbed=number(absorbed) and absorbed>0 and absorbed or 0
    local hits=math.max(0,raw-absorbed)
    local per=number(arms.damage) and arms.damage>0 and arms.damage*resisted(e,weapons.DAMAGE[arms.damageType] or '') or 0
    local stab,p=0,0
    if type(bs)=='table' and number(bs.chance) and bs.chance>0 and number(bs.multiplier) and bs.multiplier>1 then
        stab,p=(bs.multiplier-1)*per,clamp(bs.chance,0,1)
    end
    local guard=input.frame.self.guard
    local critRate=weapons.critical(threat.hitChance(arms.thac0,e.ac),critPoints(guard))*defence.critOpen
    local crits=hits*critRate
    local first,critical,critOnce,floor,conditions=0,0,0,targeting.floor(e,nil),{}
    local function strike(c,h)
        local roles=type(c)=='table' and spells.view(c,targeting.holds(e)) or nil
        if type(roles)~='table' or targeting.protected(e,c) then return end
        floor=math.min(floor,targeting.floor(e,roles))
        local times=h and h.critical and crits or hits
        if h and h.once then times=math.min(1,times) end
        if reaches(roles.damage) then
            local role=roles.damage
            local each=0
            for label,v in pairs(type(role.types)=='table' and role.types or {}) do
                if number(v) then each=each+v*resisted(e,label) end
            end
            local save=M.saveChance(role,e)
            each=each*landing(role,e)*(role.saveForHalf and 1-save/2 or 1-save)
            if h and h.critical then
                if h.once then critOnce=critOnce+each else critical=critical+each end
            elseif h and h.once then first=first+each else per=per+each end
        end
        if reaches(roles.disable) then conditions[#conditions+1]={role=roles.disable,times=times} end
        if reaches(roles.debuff) and not harm.carries(e,c,h and h.source) then
            conditions[#conditions+1]={role=roles.debuff,times=times,debuff=true}
        end
    end
    strike(arms.strike)
    for _,h in ipairs(weapons.payloads(type(guard)=='table' and guard.hits,arms)) do strike(h.strike,h) end
    -- What n hits deal: each one per, the first one first too, a backstab as likely as it comes, and
    -- the critical hits among them what their effects deal.
    local function dealt(n)
        local c=n*critRate
        return n*per+first*math.min(1,n)+p*stab+critical*c+critOnce*math.min(1,c)
    end
    -- The hits it takes to bring e to its minimum, or to death without one (extra: dealt besides).
    local function need(extra)
        if per>0 then return math.max(1,math.ceil(math.max(0,hp-floor-first-extra)/per)) end
        return first+extra>=hp and 1 or math.huge
    end
    local worth,expected=0,0
    if (per>0 or first>0 or critical>0 or critOnce>0) and hp>floor then
        expected=math.min(dealt(hits),hp-floor)
        worth=expected/maxHp
        if absorbed>0 and per>0 then
            local n=need(0)
            worth=math.max(worth,math.min(dealt(raw),hp-floor)/maxHp*n/(n+absorbed))
        end
        if floor<=0 then
            local kill=clamp(hits-need(0)+1,0,1)
            if p>0 then
                local n=need(stab)
                kill=(1-p)*kill+p*(n<=1 and 1 or clamp(hits-n+1,0,1))
            end
            worth=worth+input.mind.killBonus*kill
        end
        if e.statue==true then worth=worth*M.statueShare end
        local plan=input.plan
        if type(plan)=='table' and plan.focus==e.id then worth=worth*(1+input.mind.focusBonus*input.mind.coordination) end
        worth=worth*orders.favour(input,e)
    end
    local best,weak=0,0
    for _,x in ipairs(conditions) do
        if x.debuff then
            weak=math.max(weak,harm.debuff(x.role,e,facing(input,nil),input.tables)*orders.favour(input,e)*math.min(1,x.times))
        else best=math.max(best,disableOn(input,{resref=arms.item or ''},x.role,e,floor)*math.min(1,x.times)) end
    end
    return worth+best+weak,expected
end

-- Options of one ready spell that conjures a weapon (arms, combat-intent/weapons.lua): cast on
-- the caster, worth the hits the weapon deals in the rounds after, as many as it lasts within
-- the horizon (the enemy's images and skins taking their hits once), less the share of those
-- rounds the walk to a melee enemy takes, at the enemy in its reach where they are worth most.
-- Cost: the spell's level, and
-- for a melee weapon the hit points lost standing next to that enemy those rounds, times caution.
local function armOptions(input,row,spell,arms,out,reject)
    local frame=input.frame
    local caster=frame.self
    local mind=input.mind
    local horizon=(number(mind.horizon) and mind.horizon or 18)/6
    local rounds=math.min(number(arms.rounds) and arms.rounds or horizon,horizon)
    if rounds<=0 then reject('no-worth');return end
    local best,target,expected=0,nil,0
    for _,e in ipairs(frame.enemies) do
        local ok,why=weapons.reachable(caster,e,mind,arms)
        if ok and weapons.immuneTo(e,arms) then ok,why=false,'weapon-immunity' end
        if ok then
            local _,raw,absorbed=weapons.hits(arms.apr,arms.thac0,e)
            local worth,hp=hitsOn(input,arms,raw*rounds,e,nil,absorbed)
            -- The walk shares out over the rounds: rounds*6 / (rounds*6 + walk) of their hits.
            if not arms.ranged then worth=worth*weapons.paced(weapons.walk(caster,e)/rounds) end
            if worth>best or (worth==best and worth>0 and e.id<target) then best,target,expected=worth,e.id,hp end
        else reject(why) end
    end
    if not target then reject('no-worth');return end
    local level=number(row.level) and row.level or number(spell.level) and spell.level or 1
    local cost=mind.economy*slots(input)*M.costPerLevel*level
    local maxHp=number(caster.maxHp) and caster.maxHp>0 and caster.maxHp or nil
    if not arms.ranged and maxHp then
        for _,e in ipairs(frame.enemies) do
            if e.id==target then cost=cost+mind.caution*weapons.exposure(frame,e)*rounds/maxHp end
        end
    end
    out[#out+1]={resref=row.resref,kind='arm',mode='self',self=true,target=target,worth=best,cost=cost,
        score=best-cost,hits={target},slack=0,expected={[target]=expected},
        speed=number(spell.speed) and spell.speed or 0,item=arms.item}
end

-- The strike of the touch charge the caster holds (frame.self.charge, a weapon entry): at the
-- enemy in reach where the hit is worth most times its chance to land, with what breaking a casting
-- enemy's spell is worth, or nil; an order to always attack an enemy keeps it there while it can
-- strike that enemy (combat-intent/orders.lua). No minimum: the charge is spent already.
-- rejected (a table, optional) counts why each enemy got no strike: 'strike-' and the reason.
function M.strike(input,rejected)
    local function reject(why) if rejected then rejected['strike-'..why]=(rejected['strike-'..why] or 0)+1 end end
    local caster=input.frame.self
    local w=caster.charge
    if type(w)~='table' then return nil end
    if type(w.strike)~='table' then reject('unread');return nil end
    if weaponsOut(input) then reject('weapons-out');return nil end
    local list={}
    for _,e in ipairs(input.frame.enemies) do
        local ok,why=touch.reachable(caster,e,input.mind)
        if ok then why=touch.blocked(e,w) end
        if ok and not why then
            local worth,expected=strikeOn(input,{resref=w.spell or w.item},w,e)
            local p=touch.hitChance(caster,e,w)
            local stop=expected>0 and M.interruption(input,e,{from=0,rate=p}) or 0
            local score=worth*p+stop
            if score>0 then
                list[#list+1]={resref=w.item,spell=w.spell,kind='strike',mode='creature',target=e.id,worth=score,cost=0,
                    score=score,hits={e.id},slack=0,hit=p,expected={[e.id]=expected*p},speed=0,interrupt=stop>0 and stop or nil}
            else reject('no-worth') end
        else reject(why or 'unknown') end
    end
    local best
    for _,c in ipairs((orders.keep(input,list,{}))) do
        if not best or c.score>best.score or (c.score==best.score and c.target<best.target) then best=c end
    end
    return best
end

-- Where the spell can be aimed: enemies it can reach for creature spells; for point areas each
-- such enemy's spot (cast at the enemy itself where it can be, evaluate) and the middle of the
-- enemies around it; the caster for its own area. An aim beyond the spell's range carries the
-- seconds of the walk into range (walk).
local function aims(input,spell,mode)
    local frame=input.frame
    local caster=frame.self
    local out={}
    if mode=='self-area' then
        out[1]={point={x=caster.x,y=caster.y}}
        if spell.area.cone then out={} end
        return out
    end
    local function add(aim,walk)
        if not walk then return end
        if walk>0 then aim.walk=walk end
        out[#out+1]=aim
    end
    for _,e in ipairs(frame.enemies) do
        if mode=='point-area' then
            if targeting.alive(e) and number(e.x) and number(e.y) then
                local p={x=e.x,y=e.y}
                add({point=p,enemy=e},approach(caster,p,spell))
                local sx,sy,n=0,0,0
                for _,o in ipairs(frame.enemies) do
                    if targeting.alive(o) and number(o.x) and number(o.y) and targeting.distance(e,o)<=spell.area.radius then
                        sx,sy,n=sx+o.x,sy+o.y,n+1
                    end
                end
                if n>1 then
                    local m={x=sx/n,y=sy/n}
                    add({point=m},approach(caster,m,spell))
                end
            end
        else
            local ok,_,walk=aimable(caster,e,spell)
            if ok then add({enemy=e,point={x=e.x,y=e.y}},walk) end
        end
    end
    return out
end

local function better(a,b)
    if a.score~=b.score then return a.score>b.score end
    if a.slack~=b.slack then return a.slack>b.slack end
    if a.resref~=b.resref then return a.resref<b.resref end
    local ta,tb=a.target or -1,b.target or -1
    if ta~=tb then return ta<tb end
    local pa,pb=a.point or {x=-1,y=-1},b.point or {x=-1,y=-1}
    if pa.x~=pb.x then return pa.x<pb.x end
    return pa.y<pb.y
end

-- Whether an option is aimed at a creature it counts. An area aimed at an enemy the spell can
-- take no further (one already held, for a hold) only reaches the enemies around it.
local function centred(o)
    if not o.target then return false end
    for _,h in ipairs(o.hits) do if h==o.target then return true end end
    return false
end
-- Of two aims of one spell that hit the same enemies: the one centred on a creature it counts,
-- then the one holding its enemies furthest inside.
local function preferred(a,b)
    local ca,cb=centred(a),centred(b)
    if ca~=cb then return ca end
    return better(a,b)
end

-- Every option the caster has, best first. Aims of one spell that hit the same enemies are one
-- option, so a draw among near-best options weighs each choice once. rejected (a table,
-- optional) counts why the ready attack spells gave none: out-of-reach (no enemy in range or a
-- walk away from it), or evaluate's reason per aim.
function M.options(input,rejected)
    local out,ctx={},{}
    local function reject(why) if rejected then rejected[why]=(rejected[why] or 0)+1 end end
    -- Readiness (see the top): no touch or conjured weapon before the foes out of play are back.
    local away=number(input.calm)
    for _,row in ipairs(type(input.spells)=='table' and input.spells or {}) do
        if type(row)=='table' and number(row.ready) and row.ready>0 and row.usable then
            local spell=row.spell
            local kind,mode=M.attack(spell)
            local w=not kind and not away and input.mind.touch and touch.charge(spell)
            if w and not weaponsOut(input) and type(input.frame.self.charge)~='table' then
                touchOptions(input,row,spell,w,out,reject)
            end
            local arms=not kind and not w and not away and input.mind.weapons and weapons.conjured(spell,input.frame.self)
            if arms and not weaponsOut(input) and not input.frame.self.magicItem then
                armOptions(input,row,spell,arms,out,reject)
            end
            if kind then
                local seen,same={},{}
                local list=aims(input,spell,mode)
                if #list==0 then reject('out-of-reach') end
                for _,aim in ipairs(list) do
                    local option,why=evaluate(input,row,spell,kind,mode,aim,ctx)
                    if option then
                        local key=tostring(option.target)..':'..(option.point and option.point.x..','..option.point.y or '')
                        if not seen[key] then
                            seen[key]=true
                            local ids={}
                            for n,h in ipairs(option.hits) do ids[n]=tostring(h) end
                            table.sort(ids)
                            local set=table.concat(ids,',')
                            local at=same[set]
                            if not at then out[#out+1]=option;same[set]=#out
                            elseif preferred(option,out[at]) then out[at]=option end
                        end
                    else reject(why or 'unknown') end
                end
            end
        end
    end
    table.sort(out,better)
    return out
end

-- Attacks with the caster's weapons (M.arsenal: the one in hand, frame.self.weapon, and those it
-- could take up): with each at each enemy it reaches and can hurt, best first. Worth: a round of
-- its hits (behind Mirror Images and skins as hitsOn counts them), as much of it as counts for a
-- round after what comes first (weapons.paced): the walk
-- to a melee enemy (any enemy it sees, weapons.reach), the walk
-- into a missile's range, and taking up a weapon not in hand (weapons.switchSeconds); on a casting
-- enemy what breaking its spell is worth with the hits that come after those. Cost: for melee, the
-- hit points the caster loses to the weapons around the target that round, times caution. A weapon
-- not in hand carries its slot, ability number (abilityNum, for SelectWeaponAbility) and
-- ammunition; each option names its weapon's place in the arsenal (arm) and whether it is part of the
-- creature (body), which takes no time to take up. Not while the caster holds a touch charge (the
-- strike decides where that goes), in its own Time Stop or under Improved Alacrity.
function M.weaponOptions(input,rejected)
    local out={}
    local function reject(why) if rejected then rejected[why]=(rejected[why] or 0)+1 end end
    local frame=input.frame
    local caster=frame.self
    if type(caster.charge)=='table' or weaponsOut(input) then return out end
    local mind=input.mind
    local maxHp=number(caster.maxHp) and caster.maxHp>0 and caster.maxHp or nil
    for n,arms in ipairs(M.arsenal(caster)) do
        local switch=arms~=caster.weapon
        -- A weapon that is part of the creature takes no time to take up.
        local taking=switch and not arms.body and weapons.switchSeconds or 0
        for _,e in ipairs(frame.enemies) do
            local ok,why=weapons.reachable(caster,e,mind,arms)
            -- A missile walks into its range first, as the game's attack actions do.
            local walk=0
            if not ok and why=='out-of-reach' and arms.ranged then
                walk=weapons.approach(caster,e,number(arms.range) and arms.range or 0)
                if walk then ok,why=true,nil else walk=0 end
            end
            if ok and weapons.immuneTo(e,arms) then ok,why=false,'weapon-immunity' end
            if ok and weapons.missileBlocked(e,arms) then ok,why=false,'missile-blocked' end
            if ok then
                local _,raw,absorbed=weapons.hits(arms.apr,arms.thac0,e)
                local bs=not arms.ranged and backstab.chance(caster,arms,e) or nil
                local worth,expected=hitsOn(input,arms,raw,e,bs,absorbed)
                if worth>0 then
                    local cost=0
                    if not arms.ranged then
                        walk=weapons.walk(caster,e)
                        if maxHp then cost=mind.caution*weapons.exposure(frame,e)/maxHp end
                    end
                    local delay=walk+taking
                    worth=worth*weapons.paced(delay)
                    local stop=expected>0 and M.interruption(input,e,{from=delay,rate=raw,absorbed=absorbed}) or 0
                    worth=worth+stop
                    out[#out+1]={resref=arms.item or 'WEAPON',kind='weapon',mode='creature',target=e.id,worth=worth,
                        cost=cost,score=worth-cost,hits={e.id},slack=0,expected={[e.id]=expected},speed=0,
                        melee=not arms.ranged or nil,swing=not arms.ranged and arms.swing or nil,
                        arm=n,body=arms.body and true or nil,
                        walk=walk>0 and walk or nil,interrupt=stop>0 and stop or nil,
                        slot=switch and arms.slot or nil,abilityNum=switch and arms.abilityNum or nil,
                        ammo=switch and arms.ammo or nil,backstab=bs and bs.chance or nil}
                else reject('no-worth') end
            else reject(why) end
        end
    end
    table.sort(out,better)
    return out
end

-- The attack to make of swings (best first): the best one, but for a creature whose best attack is
-- made with a body weapon and that has another body weapon to hurt an enemy with (see the top). It
-- takes the best one as often as it takes its best option at all (mind.best), less often by
-- mind.bodyMix; otherwise it draws among the best attack of each of its body weapons, each as likely
-- as its worth's share. Without input.rng: the best one.
function M.varied(input,swings)
    local best=swings[1]
    local rng,mind=input.rng,input.mind
    local mix=number(mind.bodyMix) and mind.bodyMix or 0
    if not best or not rng or mix<=0 or best.kind~='weapon' or not best.body then return best end
    local pool,seen,total={},{},0
    for _,o in ipairs(swings) do
        if o.kind=='weapon' and o.body and o.arm~=nil and not seen[o.arm] and number(o.worth) and o.worth>0 then
            seen[o.arm]=true
            pool[#pool+1]=o;total=total+o.worth
        end
    end
    if #pool<2 then return best end
    local stay=clamp(1-(1-(number(mind.best) and mind.best or 1))*mix,0,1)
    if rng:nextInt(1,1000)<=math.floor(stay*1000+0.5) then return best end
    local roll=rng:nextInt(1,1000000)/1000000*total
    for _,o in ipairs(pool) do
        roll=roll-o.worth
        if roll<=0 then return o end
    end
    return pool[#pool]
end

-- Going behind (see the top): for an invisible caster that can backstab, a walk to the spot behind
-- each enemy whose facing it knows and that walking straight at it would not bring it behind
-- (backstab.spot), then a round of hits there whose first one is a backstab as likely as it lands,
-- for each weapon it can backstab with. Worth: as weaponOptions counts the round, less the part of
-- it the walk to that spot and a weapon switch take; on a casting enemy what breaking its spell is
-- worth with the hits after those. Cost: what standing next to the enemy costs, times caution. None
-- for a creature that cannot walk, holds a touch charge, is in its own Time Stop or under Improved
-- Alacrity, or does not see the tactic (M.tactical), and none behind an enemy the adapter found no
-- open way behind lately (input.blocked). rejected (a table, optional) counts why an enemy got none:
-- 'flank-' and the reason.
function M.flankOptions(input,rejected)
    local out={}
    local function reject(why) if rejected then rejected['flank-'..why]=(rejected['flank-'..why] or 0)+1 end end
    local frame=input.frame
    local caster=frame.self
    local mind=input.mind
    if not backstab.hidden(caster) or caster.rooted==true or type(caster.charge)=='table' or weaponsOut(input) then return out end
    local list={}
    for _,arms in ipairs(M.arsenal(caster)) do if backstab.able(caster,arms) then list[#list+1]=arms end end
    if #list==0 then return out end
    if not M.tactical(input) then reject('unnoticed');return out end
    local maxHp=number(caster.maxHp) and caster.maxHp>0 and caster.maxHp or nil
    for _,arms in ipairs(list) do
        local switch=arms~=caster.weapon
        for _,e in ipairs(frame.enemies) do
            local ok,why=weapons.reachable(caster,e,mind,arms)
            if ok and weapons.immuneTo(e,arms) then ok,why=false,'weapon-immunity' end
            if ok and not backstab.open(e) then ok,why=false,'closed' end
            if ok and blocked(input,'flank',e.id) then ok,why=false,'blocked' end
            local spot=ok and backstab.spot(e) or nil
            if ok and not spot then ok,why=false,'facing-unknown' end
            if ok and backstab.behind(caster,e)~=false then ok,why=false,'behind' end
            local walk=ok and weapons.approach(caster,spot,0) or nil
            if ok and not walk then ok,why=false,'no-walk' end
            if ok then
                local _,raw,absorbed=weapons.hits(arms.apr,arms.thac0,e)
                local bs=backstab.chance(caster,arms,e,true)
                local worth,expected=hitsOn(input,arms,raw,e,bs,absorbed)
                if worth>0 then
                    local delay=walk+(switch and weapons.switchSeconds or 0)
                    worth=worth*weapons.paced(delay)
                    local stop=expected>0 and M.interruption(input,e,{from=delay,rate=raw,absorbed=absorbed}) or 0
                    worth=worth+stop
                    local cost=maxHp and mind.caution*weapons.exposure(frame,e)/maxHp or 0
                    out[#out+1]={resref='FLANK',kind='flank',mode='point',point=spot,target=e.id,worth=worth,cost=cost,
                        score=worth-cost,hits={e.id},slack=0,expected={[e.id]=expected},speed=0,melee=true,walk=walk,
                        interrupt=stop>0 and stop or nil,backstab=bs and bs.chance or nil,item=arms.item,
                        slot=switch and arms.slot or nil,abilityNum=switch and arms.abilityNum or nil}
                else reject('no-worth') end
            else reject(why) end
        end
    end
    table.sort(out,better)
    return out
end
-- What hiding is worth to a creature that can backstab (see the top): the most the first hit of a
-- round after it gains as a backstab on an enemy it could stab, over that round's hits without one
-- (hitsOn), less the part of the round the walk to the enemy takes (to the spot behind it when
-- walking straight at it would not bring it behind, as the creature then goes behind): {worth,
-- target}, or nil. None for a creature that does not fight with its weapons, is hidden already,
-- holds a touch charge, is in its own Time Stop or under Improved Alacrity, or does not see the
-- tactic (M.tactical). The time the hide itself takes is the defence's to count
-- (combat-intent/defence.lua, input.hideOpening).
function M.hideOpening(input)
    local frame=input.frame
    local caster=frame.self
    if input.mind.weapons~=true or backstab.hidden(caster) or type(caster.charge)=='table' or weaponsOut(input) then
        return nil
    end
    local best,at=0,nil
    for _,arms in ipairs(M.arsenal(caster)) do
        if backstab.able(caster,arms) then
            local switch=arms~=caster.weapon and weapons.switchSeconds or 0
            for _,e in ipairs(frame.enemies) do
                if weapons.reachable(caster,e,input.mind,arms) and not weapons.immuneTo(e,arms) and backstab.open(e) then
                    local behind=backstab.behind(caster,e)
                    local walk=weapons.walk(caster,e)
                    if behind==false then
                        local spot=backstab.spot(e)
                        walk=spot and weapons.approach(caster,spot,0) or nil
                    end
                    if walk then
                        local _,raw,absorbed=weapons.hits(arms.apr,arms.thac0,e)
                        local bs=backstab.chance(caster,arms,e,behind==false or nil,true)
                        local gain=(hitsOn(input,arms,raw,e,bs,absorbed)-hitsOn(input,arms,raw,e,nil,absorbed))*
                            weapons.paced(walk+switch)
                        if gain>best or (gain==best and gain>0 and e.id<at) then best,at=gain,e.id end
                    end
                end
            end
        end
    end
    if best<=0 or not M.tactical(input) then return nil end
    return {worth=best,target=at}
end

-- Kiting (see the top): steps of kiteSeconds at the caster's speed (zones.walkSpeed without one)
-- straight away from the melee enemies close to it (pressing) and in eight directions; the step
-- worth most, then the one furthest from its nearest enemy, with the next four as exits (the
-- adapter walks to the first open one). Worth: the hit points a round the melee weapons take from
-- the caster where it stands less where the step ends (weapons.meleeAt), as a share of its own,
-- times caution, for the seconds of the step (a round at most), and what walking there is worth in
-- the zones (zones.delta). When best, the creature's best choice, is a cast that damage can break
-- (breakable), the step is worth that cast's score besides, times how much less likely a melee hit
-- breaks it (meleeHits: one hit or more lands while it casts) once the step is over than where it
-- stands, the casting beginning when its casting aura frees. None for a creature that cannot walk,
-- is invisible, holds a touch charge, is in its own Time Stop or under Improved Alacrity, has
-- neither a missile weapon to shoot an enemy with (shooting) nor such a cast as its best choice,
-- does not see the tactic (M.tactical; a creature whose body shoots needs no wit for it,
-- mind.bodyRetreat), found no open step lately (input.blocked) or stepped away
-- within kiteGap seconds (input.kited, by input.tick). The option names the cast (cast) and the
-- chances it breaks here and after the step (breaks). rejected (a table, optional) counts why there
-- is none: 'kite-' and the reason.
function M.kite(input,rejected,best)
    local function reject(why) if rejected then rejected['kite-'..why]=(rejected['kite-'..why] or 0)+1 end end
    local frame=input.frame
    local caster=frame.self
    local maxHp=number(caster.maxHp) and caster.maxHp>0 and caster.maxHp or nil
    if not maxHp or not number(caster.x) or not number(caster.y) or caster.rooted==true or
        targeting.has(caster.state,UNSEEN) or type(caster.charge)=='table' or weaponsOut(input) then return nil end
    local close=pressing(input)
    if #close==0 then return nil end
    local cast=breakable(best) and best or nil
    if not cast and not shooting(input) then reject('no-ranged');return nil end
    -- A creature whose body shoots steps back to use it by its kind, not by its wit.
    local instinct=input.mind.bodyRetreat==true and shooting(input,true)
    if not instinct and not M.tactical(input) then reject('unnoticed');return nil end
    if blocked(input,'kite') then reject('blocked');return nil end
    if number(input.kited) and not (number(input.tick) and input.tick-input.kited>=M.kiteGap*M.ticksPerSecond) then
        reject('recent');return nil
    end
    local here=weapons.meleeAt(frame,caster)
    local seconds=cast and cast.speed*zones.speedSeconds or 0
    local start=number(caster.aura) and caster.aura>0 and caster.aura or 0
    local brokenHere=cast and 1-math.exp(-meleeHits(input,caster,start,seconds,0)) or 0
    if here<=0 and brokenHere<=0 then reject('no-harm');return nil end
    local far=(number(caster.speed) and caster.speed>0 and caster.speed or zones.walkSpeed)*M.kiteSeconds
    local ax,ay=0,0
    for _,o in ipairs(close) do
        local dx,dy=offset(o,caster)
        local d=math.sqrt(dx*dx+dy*dy)
        if d>0 then ax,ay=ax+dx/d,ay+dy/d end
    end
    local ways={}
    local n=math.sqrt(ax*ax+ay*ay)
    if n>1e-9 then ways[1]={ax/n,ay/n} end
    for k=0,7 do ways[#ways+1]={math.cos(k*math.pi/4),math.sin(k*math.pi/4)} end
    local share=math.min(1,M.kiteSeconds/M.ROUND)
    local steps,seen={},{}
    for _,v in ipairs(ways) do
        local p={x=math.floor(caster.x+v[1]*far+0.5),y=math.floor(caster.y+v[2]*far*3/4+0.5)}
        local key=p.x..','..p.y
        if p.x>=0 and p.y>=0 and not seen[key] then
            seen[key]=true
            local nearest=math.huge
            for _,o in ipairs(frame.enemies) do
                if type(o)=='table' and targeting.alive(o) then nearest=math.min(nearest,targeting.distance(o,p)) end
            end
            local worth=input.mind.caution*(here-weapons.meleeAt(frame,p))/maxHp*share+zones.delta(input,p)
            local broken=0
            if cast then
                broken=1-math.exp(-meleeHits(input,p,math.max(M.kiteSeconds,start),seconds,M.react))
                worth=worth+cast.score*(brokenHere-broken)
            end
            steps[#steps+1]={point=p,worth=worth,nearest=nearest,broken=broken}
        end
    end
    table.sort(steps,function(a,b)
        if a.worth~=b.worth then return a.worth>b.worth end
        if a.nearest~=b.nearest then return a.nearest>b.nearest end
        if a.point.x~=b.point.x then return a.point.x<b.point.x end
        return a.point.y<b.point.y
    end)
    local step=steps[1]
    if not step or step.worth<=0 then reject('no-worth');return nil end
    local exits={}
    for i=2,math.min(#steps,5) do if steps[i].worth>0 then exits[#exits+1]=steps[i].point end end
    return {resref='KITE',kind='kite',mode='point',point=step.point,worth=step.worth,cost=0,score=step.worth,hits={},
        slack=0,speed=0,walk=M.kiteSeconds,exits=exits,cast=cast and cast.resref or nil,
        breaks=cast and {here=brokenHere,after=step.broken} or nil}
end

-- Positioning (see the top): while the casting aura runs (aura: its seconds left), a walk toward
-- the spot cast o goes off from, for the seconds until the aura frees (aura less auraLead) at most
-- and no further than that spot: the longest of positionSteps of that way that ends where no
-- enemy's melee weapon reaches (weapons.meleeAt). Worth: what o gains as its walk into range
-- shrinks by that much (weapons.paced of the walk left against the whole walk, on o's worth before
-- its walk lowered it), and what standing there is worth in the zones (zones.delta). None for a
-- cast without a walk into range, an aim that cannot be found, a creature that cannot walk, a walk
-- shorter than positionMin, a creature that does not see the tactic (M.tactical), or one that found
-- no open way into position lately (input.blocked). rejected (a table, optional) counts why there is
-- none: 'position-' and the reason.
function M.position(input,o,aura,rejected)
    local function reject(why) if rejected then rejected['position-'..why]=(rejected['position-'..why] or 0)+1 end end
    if type(o)~='table' or not number(o.walk) or o.walk<=0 or not number(o.worth) or not number(aura) then return nil end
    local frame=input.frame
    local caster=frame.self
    if caster.rooted==true or not number(caster.x) or not number(caster.y) then return nil end
    local seconds=math.min(o.walk,aura-M.auraLead)
    if seconds<=0 then return nil end
    -- Where the cast is aimed: its point, else the creature it is cast at.
    local p=o.point
    if p==nil and o.target~=nil then
        for _,list in ipairs({frame.enemies,type(frame.allies)=='table' and frame.allies or {}}) do
            for _,c in ipairs(list) do if type(c)=='table' and c.id==o.target then p=c end end
        end
    end
    local d=targeting.distance(caster,p)
    if d==math.huge or d<=0 then reject('no-aim');return nil end
    if not M.tactical(input) then reject('unnoticed');return nil end
    if blocked(input,'position') then reject('blocked');return nil end
    local speed=weapons.speed(caster)
    local far=math.min(d,seconds*speed)
    local spot,walked
    for _,share in ipairs(M.positionSteps) do
        local t=far*share/d
        local at={x=math.floor(caster.x+(p.x-caster.x)*t+0.5),y=math.floor(caster.y+(p.y-caster.y)*t+0.5)}
        if weapons.meleeAt(frame,at)<=0 then spot,walked=at,far*share;break end
    end
    if not spot then reject('melee');return nil end
    if walked<M.positionMin then reject('short');return nil end
    local moved=walked/speed
    local raw=(o.worth-(number(o.interrupt) and o.interrupt or 0))/weapons.paced(o.walk)
    local worth=raw*(weapons.paced(math.max(0,o.walk-moved))-weapons.paced(o.walk))+zones.delta(input,spot)
    if worth<=0 then reject('no-worth');return nil end
    return {resref='POSITION',kind='position',mode='point',point=spot,worth=worth,cost=0,score=worth,hits={},
        slack=0,speed=0,walk=moved,cast=o.resref,toward=o.target}
end
-- Whether o, the best of the options, is the cast the creature makes once the aura frees (pick):
-- worth the minimum and more than the best attack, or worth something with no attack worth making.
local function casts(input,o,swing,swinging)
    if type(o)~='table' or not number(o.score) then return false end
    if o.score>=input.mind.minValue then return not (swing and swing.score>o.score) end
    return not swinging and o.score>0
end

-- Jumps into the fight (see the top), best first: for each enemy the weapon in hand could hit in
-- melee a long walk away, the teleport search.jump picks for the walk to a spot landShort short of
-- the enemy on the way, cast at that spot or as far toward it as the teleport reaches. Worth: a
-- round of the weapon's hits on the enemy as weaponOptions counts it, paced by the casting and any
-- walk left after landing; on a casting enemy what breaking its spell is worth with the hits that
-- come after the casting aura, the casting and that walk. Cost: the teleport's level as for a spell,
-- and the hit points lost standing next to the enemy, times caution. Not for a creature that does
-- not chase, cannot walk or holds a touch charge, in its own Time Stop or under Improved Alacrity,
-- or that does not see the tactic (M.tactical). rejected (a table, optional) counts why an enemy
-- got no jump: 'jump-' and the reason.
function M.jumpOptions(input,rejected)
    local out={}
    local function reject(why) if rejected then rejected['jump-'..why]=(rejected['jump-'..why] or 0)+1 end end
    local frame=input.frame
    local caster=frame.self
    local arms=caster.weapon
    local mind=input.mind
    if type(input.teleports)~='table' or #input.teleports==0 or mind.chase~=true then return out end
    if type(arms)~='table' or not number(arms.damage) or arms.ranged or type(caster.charge)=='table' or
        weaponsOut(input) or caster.rooted==true then return out end
    if not M.tactical(input) then reject('unnoticed');return out end
    local maxHp=number(caster.maxHp) and caster.maxHp>0 and caster.maxHp or nil
    local aura=number(caster.aura) and caster.aura>0 and caster.aura or 0
    for _,e in ipairs(frame.enemies) do
        -- A teleport goes where a walk cannot: an enemy others keep the caster from counts too.
        local ok,why=weapons.reachable(caster,e,mind,arms,true)
        if ok and weapons.immuneTo(e,arms) then ok,why=false,'weapon-immunity' end
        local d=ok and targeting.distance(caster,e) or 0
        if ok and d-M.landShort<search.jumpMin then ok,why=false,'near' end
        if ok then
            local walk=d-M.landShort
            local spot={x=caster.x+(e.x-caster.x)*walk/d,y=caster.y+(e.y-caster.y)*walk/d}
            local o,at=search.jump(input,spot,walk,true)
            local _,raw,absorbed=weapons.hits(arms.apr,arms.thac0,e)
            local worth,expected=hitsOn(input,arms,raw,e,nil,absorbed)
            if o and worth>0 then
                local landed={}
                for k,v in pairs(caster) do landed[k]=v end
                landed.x,landed.y=at.x,at.y
                local cast=(number(o.speed) and o.speed or 0)*zones.speedSeconds
                local rest=weapons.walk(landed,e)
                worth=worth*weapons.paced(cast+rest)
                local stop=expected>0 and M.interruption(input,e,{from=aura+cast+rest,rate=raw,absorbed=absorbed}) or 0
                worth=worth+stop
                local level=number(o.level) and o.level or 1
                local cost=mind.economy*slots(input)*M.costPerLevel*level
                if maxHp then cost=cost+mind.caution*weapons.exposure(frame,e)/maxHp end
                out[#out+1]={resref=o.resref,kind='teleport',mode='point',point=at,target=e.id,worth=worth,cost=cost,
                    score=worth-cost,hits={e.id},slack=0,speed=number(o.speed) and o.speed or 0,level=level,
                    innate=o.innate,melee=true,interrupt=stop>0 and stop or nil}
            elseif not o then reject('no-teleport')
            else reject('no-worth') end
        else reject(why) end
    end
    table.sort(out,better)
    return out
end

-- The input without its releases (sequencers and triggers): under Improved Alacrity SCS keeps
-- them for later (caster_definitions.ssl), and so does the engine.
function M.unreleased(input)
    local kept,left=false,{}
    for _,row in ipairs(type(input.spells)=='table' and input.spells or {}) do
        if type(row)=='table' and type(row.spell)=='table' and row.spell.release then kept=true else left[#left+1]=row end
    end
    if not kept then return input end
    local view={}
    for k,v in pairs(input) do view[k]=v end
    view.spells=left
    return view
end

-- The input as the caster sees it in its own Time Stop: what it cast in the stop
-- (input.stopCasts: {kind, hits, expected, spell}) lands when time resumes, so the enemies it
-- disabled count as held, the hit points it is expected to have taken come off (hpNow keeps the
-- hit points they have now) and the enemies its spells reach carry them (carried: a debuff is not
-- cast twice). The same input outside its own stop.
function M.frozen(input)
    if not openers.ownStop(input) or type(input.stopCasts)~='table' or #input.stopCasts==0 then return input end
    local held,lost,carried={},{},{}
    for _,cast in ipairs(input.stopCasts) do
        if type(cast)=='table' then
            if cast.kind=='disable' and type(cast.hits)=='table' then
                for _,id in ipairs(cast.hits) do held[id]=true end
            end
            if type(cast.expected)=='table' then
                for id,hp in pairs(cast.expected) do if number(hp) then lost[id]=(lost[id] or 0)+hp end end
            end
            if type(cast.spell)=='string' and type(cast.hits)=='table' then
                for _,id in ipairs(cast.hits) do carried[id]=carried[id] or {};carried[id][cast.spell]=true end
            end
        end
    end
    local enemies={}
    for n,e in ipairs(input.frame.enemies) do
        if type(e)=='table' and (held[e.id] or lost[e.id] or carried[e.id]) then
            local c={}
            for k,v in pairs(e) do c[k]=v end
            if held[e.id] then c.held=math.max(number(c.held) and c.held or 0,1);c.taken=true end
            if lost[e.id] and number(c.hp) then c.hpNow=c.hp;c.hp=c.hp-lost[e.id] end
            if carried[e.id] then
                c.carried={}
                for res in pairs(type(e.carried)=='table' and e.carried or {}) do c.carried[res]=true end
                for res in pairs(carried[e.id]) do c.carried[res]=true end
            end
            enemies[n]=c
        else enemies[n]=e end
    end
    local frame,view={},{}
    for k,v in pairs(input.frame) do frame[k]=v end
    frame.enemies=enemies
    for k,v in pairs(input) do view[k]=v end
    view.frame=frame
    return view
end

-- The input its defences are weighed on while the creature readies itself (see the top), or nil:
-- with no enemy in sight, the foes out of play it guards (input.returning: each as an enemy in sight
-- is read, where it will be back, with back, the seconds until it likely is; unknown counts as now,
-- and one that is never back, under a charm without an end, is left out) stand in its frame as
-- enemies, and calm holds the seconds until the first of them is back.
function M.readied(input)
    if #input.frame.enemies>0 or type(input.returning)~='table' then return nil end
    local enemies,calm={},math.huge
    for _,e in ipairs(input.returning) do
        if type(e)=='table' and targeting.alive(e) and e.back~=math.huge then
            enemies[#enemies+1]=e
            calm=math.min(calm,number(e.back) and math.max(0,e.back) or 0)
        end
    end
    if #enemies==0 then return nil end
    local frame,view={},{}
    for k,v in pairs(input.frame) do frame[k]=v end
    frame.enemies=enemies
    for k,v in pairs(input) do view[k]=v end
    -- The fight from the foes' return is theirs against the caster's side, not the one the group
    -- knows now (input.fight), whose foes are away.
    view.frame,view.calm,view.fight=frame,calm,nil
    return view
end

-- The enemies of the input's frame by id.
local function placed(input)
    local at={}
    for _,e in ipairs(input.frame.enemies) do if type(e)=='table' and e.id~=nil then at[e.id]=e end end
    return at
end

-- Doing nothing for the given seconds, then deciding again.
function M.wait(seconds)
    return {resref='WAIT',kind='wait',mode='none',worth=0,cost=0,score=0,hits={},slack=0,speed=0,
        seconds=number(seconds) and math.max(0,seconds) or 0}
end

-- The choice without a way out of the zones (M.decide).
local function pick(input)
    local mind=input.mind
    local rejected={}
    local zoned=zones.active(input)
    if mind.touch then
        local strike=M.strike(input,rejected)
        if strike then
            if zoned then zones.adjust(input,strike,placed(input)) end
            return strike,'strike',{strike}
        end
    end
    local aura=input.frame.self.aura
    aura=number(aura) and aura>0 and aura or 0
    local busy=aura>M.auraLead
    if mind.openers then
        local opener=openers.choose(input)
        if opener then
            if busy then return M.wait(aura-M.auraLead),'aura',{opener} end
            return opener,'opener',{opener}
        end
    end
    input=M.frozen(input)
    if input.frame.self.alacrity==true then input=M.unreleased(input) end
    -- What a hide is worth for the backstab after it (M.hideOpening) counts in the defences that
    -- hide the caster.
    if input.hideOpening==nil and mind.weapons then
        local view={}
        for k,v in pairs(input) do view[k]=v end
        view.hideOpening=M.hideOpening(input) or false
        input=view
    end
    -- What the creature readies itself with (see the top) is weighed on the foes out of play.
    local ready=M.readied(input)
    local options={}
    local function readying(list)
        for _,o in ipairs(list) do
            if ready then o.ready,o.calm=true,ready.calm end
            options[#options+1]=o
        end
    end
    readying(M.options(ready or input,rejected))
    readying(defence.options(ready or input,rejected))
    for _,o in ipairs(care.options(input,rejected)) do options[#options+1]=o end
    readying(summons.options(ready or input,rejected))
    for _,o in ipairs(removal.options(input,rejected,function(s) return M.attack(s)~=nil end)) do options[#options+1]=o end
    if mind.weapons then
        for _,o in ipairs(M.jumpOptions(input,rejected)) do options[#options+1]=o end
    end
    -- A weapon attack spends nothing: it needs no minimum worth, and it is taken over a spell
    -- only when it is worth more. Going behind an enemy first is one of them.
    local swings=mind.weapons and M.weaponOptions(input,rejected) or {}
    if mind.weapons then
        for _,o in ipairs(M.flankOptions(input,rejected)) do swings[#swings+1]=o end
        table.sort(swings,better)
    end
    if zoned then
        local at=placed(input)
        for _,o in ipairs(options) do zones.adjust(input,o,at) end
        for _,o in ipairs(swings) do zones.adjust(input,o,at) end
        table.sort(swings,better)
    end
    -- An order to always attack an enemy keeps the attacks on it while one reaches it.
    options,swings=orders.keep(input,options,swings)
    table.sort(options,better)
    -- A creature uses all its body's weapons (M.varied).
    local swing=M.varied(input,swings)
    local function all()
        local list={}
        for _,o in ipairs(options) do list[#list+1]=o end
        for _,o in ipairs(swings) do list[#list+1]=o end
        table.sort(list,better)
        return list
    end
    -- Whether an attack is worth making at all: one that hurts the enemy for a creature that always
    -- attacks (what standing next to the enemy costs only chose the target), else one worth more
    -- than that cost.
    local value=swing and (mind.alwaysAttack and swing.worth or swing.score) or 0
    local swinging=swing~=nil and value>0
    -- A step away from the melee enemies close by comes first when what it keeps off beats what its
    -- seconds give up: the part of a round of the best attack they take, and of the best cast the
    -- part past the casting aura, which the cast waits for anyway (SCS's mages step away while their
    -- casting pause runs, [src] mage/ssl/meleeblocks/standard_mage.ssl).
    local kite=mind.weapons and M.kite(input,rejected,options[1])
    if kite then
        local best=options[1] and number(options[1].score) and math.max(0,options[1].score) or 0
        local share=math.min(1,M.kiteSeconds/M.ROUND)
        local held=busy and math.max(0,math.min(M.ROUND,M.kiteSeconds)-aura)/M.ROUND or share
        if kite.score>math.max(value*share,best*held) then
            local list=all()
            table.insert(list,1,kite)
            return kite,'kite',list
        end
    end
    -- While the aura runs, casts and drinks wait for it. An attack now holds the best of them back
    -- by the part of a round the aura leaves of the attack's round, and is made when it is worth
    -- more than that part of the best. A walk into position for the cast made once the aura frees
    -- (M.position) comes first when it is worth more than such an attack.
    if busy then
        local best=options[1] and number(options[1].score) and math.max(0,options[1].score) or 0
        local swung=swinging and value-best*math.max(0,M.ROUND-aura)/M.ROUND or 0
        local step=casts(input,options[1],swing,swinging) and M.position(input,options[1],aura,rejected)
        if step and step.score>math.max(0,swung) then
            local list=all()
            table.insert(list,1,step)
            return step,'position',list
        end
        if swung>0 then return swing,'weapon',all() end
        return M.wait(aura-M.auraLead),'aura',all(),rejected
    end
    -- The fight's designer's opener (orders.opener): its step to take now comes before the ranking,
    -- marked with its number for the adapter.
    local opening=orders.openerStep(input,options)
    if opening then
        local d=opening.option or M.wait(opening.watch)
        d.openerStep=opening.step
        return d,opening.option and 'opener-step' or 'opener-watch',all()
    end
    if #options==0 then
        if swinging then return swing,'weapon',all() end
        return M.wait(M.idle),'no-option',options,rejected
    end
    -- Under Improved Alacrity a slow spell waits while a quick one reaches the minimum worth
    -- (SCS's slow spells and its compromise).
    if input.frame.self.alacrity==true and number(mind.slowSpeed) then
        local quick={}
        for _,o in ipairs(options) do if not (number(o.speed) and o.speed>=mind.slowSpeed) then quick[#quick+1]=o end end
        if quick[1] and quick[1].score>=mind.minValue then options=quick end
    end
    -- The attack, or the best buff potion or instant ability on itself before it (see the top): it
    -- is taken when it is worth more than the part of the attack its moment takes.
    local boost
    for _,o in ipairs(options) do
        if (o.use or (o.self and o.speed==0)) and o.boosts and number(o.score) and o.score>0 then boost=o;break end
    end
    local function attack()
        if boost and boost.score>value*(1-weapons.paced(M.drinkSeconds)) then return boost,'drink',all() end
        return swing,'weapon',all()
    end
    local best=options[1]
    if best.score<mind.minValue then
        if swinging then
            -- A jump into the fight ends next to an enemy as the walk does, sooner: the best one is
            -- taken over the attack when it is worth more.
            for _,o in ipairs(options) do
                if o.kind=='teleport' and o.melee then
                    if o.score>swing.score then return o,'jump',all() end
                    break
                end
            end
            return attack()
        end
        -- No attack is worth anything: the best that is worth something, rather than nothing. What
        -- a creature would only ready itself with is none of that: it guards instead.
        for _,o in ipairs(options) do
            if o.score<=0 then break end
            if not o.ready then return o,'weak',options end
        end
        return M.wait(M.idle),'nothing-good',options,rejected
    end
    if swing and swing.score>best.score then return attack() end
    local rng=input.rng
    if not rng or rng:nextInt(1,1000)<=math.floor(mind.best*1000+0.5) then return best,'best',options end
    local floor=math.max(mind.minValue,best.score-math.abs(best.score)*mind.band)
    local pool={}
    for _,o in ipairs(options) do if o.score>=floor then pool[#pool+1]=o end end
    return pool[rng:nextInt(1,#pool)],'near-best',options
end

-- The attack, defence, heal or cure, summons, removal, opener, strike, weapon attack, jump into the
-- fight, step away from melee enemies ('kite'), walk into position for the next cast ('position'),
-- way out of a zone or wait to do now, and why
-- ('aura', 'no-option' or 'nothing-good' for a wait; 'jump' for a jump taken over the attack it
-- brings sooner; 'drink' for a buff potion drunk before the attack; 'opener-step' and 'opener-watch'
-- for a step of the designer's opener, the decision marked openerStep), or nil and why for bad input; the options come along for the log, and with a wait for want of options the
-- count of reasons the ready spells gave none. Leaving costs no spell, only the seconds of the
-- walk: it comes first when it is worth more than that share of a round of the choice, or when the
-- pain drives a dull creature out (forced). Spell slots cost input.slots of their price,
-- M.slotShare's when it is not given. The creature's target order (input.ordered, false for none;
-- combat-intent/orders.lua) and whether it sees a tactic's chance (input.tactical, M.notices) are
-- worked out once, when not given; an attack on an enemy its order names is marked ordered.
function M.decide(input)
    if type(input)~='table' or type(input.frame)~='table' or type(input.frame.self)~='table' or
        type(input.frame.enemies)~='table' or type(input.mind)~='table' then return nil,'bad-input',{} end
    local view={}
    for k,v in pairs(input) do view[k]=v end
    if view.slots==nil then view.slots=M.slotShare(input) end
    if view.ordered==nil then view.ordered=orders.of(view) or false end
    if view.tactical==nil then view.tactical=M.notices(view) end
    input=view
    local d,why,options,rejected=pick(input)
    if d and orders.on(input,d) then d.ordered=true end
    local escape=zones.active(input) and zones.escape(input) or nil
    if escape then
        local score=d and number(d.score) and d.score or 0
        if escape.forced or escape.worth>math.max(0,score)*escape.walk/zones.ROUND then
            local list={escape}
            for _,o in ipairs(type(options)=='table' and options or {}) do list[#list+1]=o end
            return escape,'escape',list
        end
    end
    return d,why,options,rejected
end
return M
