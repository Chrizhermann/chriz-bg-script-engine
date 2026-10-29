-- Profiles and wit (combat-intent/mind.lua): race groups, meant stats, the difficulty shift and
-- its tops, overrides and the profile a wit makes. No game data.
local mind=require('combat-intent.mind')
local groups=0
local function near(a,b) return math.abs(a-b)<1e-9 end

-- 1. Kinds by IDS name: casters think as the high group whatever their race; then the class, the
-- race and the general. Animals, animated weapons, the mindless dead, golems and slimes are dull;
-- ogres, trolls, giants and other brutes low; beholders, mind flayers, vampires, dragons and
-- demons high; the peoples and anything not listed average.
assert(mind.group({family='mage',general='ANIMAL'})=='high' and mind.group({family='priest',race='SKELETON'})=='high')
assert(mind.group({family='monster',general='ANIMAL'})=='dull' and mind.group({general='WEAPON'})=='dull')
assert(mind.group({general='UNDEAD',race='ZOMBIE'})=='dull' and mind.group({general='HUMANOID',race='GIBBERLING'})=='dull')
assert(mind.group({general='GIANTHUMANOID',race='GOLEM'})=='dull' and mind.group({general='UNDEAD',class='SKELETON'})=='dull')
assert(mind.group({general='MONSTER',race='SLIME'})=='dull' and mind.group({general='MONSTER',class='GOLEM_ICE'})=='dull')
-- Skeletons by race too, but a skeleton warrior is no mindless skeleton; a dread wolf filed as
-- undead is a wolf.
assert(mind.group({general='UNDEAD',race='SKELETON',class='FIGHTER'})=='dull')
assert(mind.group({general='UNDEAD',race='SKELETON',class='SKELETON_WARRIOR'})=='average')
assert(mind.group({general='UNDEAD',race='WOLF',class='WOLF_DREAD'})=='dull')
assert(mind.group({family='fighter',general='GIANTHUMANOID',race='OGRE'})=='low' and
    mind.group({family='monster',general='MONSTER',race='TROLL'})=='low' and mind.group({race='GIANT'})=='low')
assert(mind.group({general='MONSTER',race='BEHOLDER'})=='high' and mind.group({race='MIND_FLAYER'})=='high' and
    mind.group({race='WILL-O-WISP'})=='high' and mind.group({race='SUCCUBUS'})=='high')
-- A man, an orc, a race no group lists, a giant humanoid without a race, numbers instead of names
-- and nothing at all: average.
assert(mind.group({family='fighter',general='HUMANOID',race='HUMAN'})=='average' and mind.group({race='ORC'})=='average')
assert(mind.group({race='NEWRACE'})=='average' and mind.group({general='GIANTHUMANOID'})=='average')
assert(mind.group({general=2,race=148,class=134})=='average' and mind.group({})=='average')
groups=groups+1

-- 2. Meant stats: template pairs and an unset INT say nothing.
assert(not mind.meant(9,9) and not mind.meant(16,9) and not mind.meant(0,12) and not mind.meant(nil,9))
assert(mind.meant(7,7) and mind.meant(9,12) and mind.meant(16,16) and mind.meant(3,9))
assert(mind.step(5)=='dull' and mind.step(6)=='normal' and mind.step(13)=='normal' and mind.step(14)=='clever')
groups=groups+1

-- 3. Wit: the kind's INT where the file says nothing, else its own; WIS sets the danger weight;
-- the difficulty shifts both by two a step from Normal.
local wolf={family='monster',general='ANIMAL',int=9,wis=9,difficulty=3}
local w=mind.wit(wolf)
assert(w.step=='dull' and w.from=='kind' and w.group=='dull' and w.int==1 and near(w.danger,1))
-- Really dull creatures stay dull on Insane, though they take harm more seriously there.
wolf.difficulty=5;w=mind.wit(wolf)
assert(w.step=='dull' and w.int==5 and w.wis==14 and near(w.danger,1.2))
-- An ettin (7/7) is normal and careless; one of INT 5 is dull on Normal and normal on Insane.
w=mind.wit({family='fighter',general='GIANTHUMANOID',race='ETTIN',int=7,wis=7,difficulty=3})
assert(w.step=='normal' and w.from=='stats' and w.group=='low' and near(w.danger,0.85))
assert(mind.wit({race='ETTIN',int=5,wis=7,difficulty=3}).step=='dull')
assert(mind.wit({race='ETTIN',int=5,wis=7,difficulty=5}).step=='normal')
-- An ogre with the template 16/9 is normal, dull below Normal and never clever, not even on
-- Insane (Christopher, 2026-10-25: "Sowas darf nicht klug sein").
w=mind.wit({family='fighter',general='GIANTHUMANOID',race='OGRE',int=16,wis=9,difficulty=3})
assert(w.step=='normal' and w.from=='kind' and w.group=='low' and w.int==7 and near(w.danger,1))
w=mind.wit({family='fighter',race='OGRE',int=16,wis=9,difficulty=5})
assert(w.step=='normal' and w.int==11)
assert(mind.wit({family='fighter',race='OGRE',int=16,wis=9,difficulty=2}).step=='dull')
-- A man without meant values is normal, and clever on Insane, as before.
assert(mind.wit({family='fighter',race='HUMAN',int=9,wis=9,difficulty=3}).step=='normal')
assert(mind.wit({family='fighter',race='HUMAN',int=9,wis=9,difficulty=5}).step=='clever')
-- A mage with 9 in every stat is clever, and normal on the easiest setting; a priest of INT 10
-- and WIS 17 is normal and careful; a mind flayer of INT 18 is clever, and a beholder with the
-- template clever by its kind.
assert(mind.wit({family='mage',general='HUMANOID',int=9,wis=9,difficulty=3}).step=='clever')
assert(mind.wit({family='mage',general='HUMANOID',int=9,wis=9,difficulty=1}).step=='normal')
w=mind.wit({family='priest',general='HUMANOID',int=10,wis=17,difficulty=3})
assert(w.step=='normal' and near(w.danger,1.35))
assert(mind.wit({family='monster',general='MONSTER',int=18,wis=15,difficulty=3}).step=='clever')
w=mind.wit({family='monster',general='MONSTER',race='BEHOLDER',int=16,wis=9,difficulty=3})
assert(w.step=='clever' and w.from=='kind' and w.group=='high' and w.int==15)
assert(mind.wit({family='monster',race='BEHOLDER',int=16,wis=9,difficulty=2}).step=='normal')
-- Difficulty outside 1 to 5 is held to it; without one nothing shifts.
assert(mind.wit({general=5,int=12,wis=10,difficulty=9}).int==16 and mind.wit({general=5,int=12,wis=10,difficulty=0}).int==8)
assert(mind.wit({general=5,int=12,wis=10}).int==12)
-- The danger weight stays within its bounds.
assert(near(mind.wit({general=1,int=12,wis=25}).danger,1.5) and near(mind.wit({general=1,int=12,wis=1}).danger,0.55))
assert(near(mind.wit({general=1,int=12,wis=1,difficulty=1}).danger,0.5))
assert(mind.wit(nil).step=='normal' and mind.wit('x').from=='kind')
groups=groups+1

-- 4. Overrides by resref: a step and a WIS that stand for the creature's own (a dull, unwise but
-- seasoned warrior made tactical); the difficulty shifts them too.
local overrides={DUMWAR={step='clever',wis=8},CAREFUL={wis=18},ODD={step='genius'}}
w=mind.wit({resref='dumwar',general=1,int=5,wis=6,difficulty=3},overrides)
assert(w.step=='clever' and w.from=='override' and near(w.danger,0.9))
assert(mind.wit({resref='DUMWAR',general=1,int=5,wis=6,difficulty=1},overrides).step=='normal')
w=mind.wit({resref='CAREFUL',general=1,int=7,wis=7,difficulty=3},overrides)
assert(w.step=='normal' and w.from=='stats' and near(w.danger,1.4))
assert(mind.wit({resref='ODD',general=1,int=4,wis=7},overrides).step=='dull')
assert(mind.wit({resref='OTHER',general=1,int=4,wis=7},overrides).from=='stats')
groups=groups+1

-- 5. The profile a wit makes, and profile checks for the new knobs.
local base=mind.new()
assert(base.wit=='clever' and base.danger==1 and base.clouds=='learned')
local clever=mind.withWit(base,{step='clever',danger=1.2})
assert(clever.wit=='clever' and clever.danger==1.2 and clever.clouds=='learned')
local normal=mind.withWit(base,{step='normal',danger=0.8})
assert(normal.wit=='normal' and normal.clouds=='best' and base.clouds=='learned')
assert(mind.withWit(base,{step='dull',danger=1}).clouds=='once')
assert(mind.withWit(mind.new({clouds='once'}),{step='normal',danger=1}).clouds=='once')
normal.allySpells.X=true
assert(base.allySpells.X==nil)
local bad,why=mind.new({wit='genius'});assert(bad==nil and why=='wit')
bad,why=mind.new({danger=0});assert(bad==nil and why=='danger')
assert(mind.new({wit='dull',danger=0.6}).wit=='dull')
groups=groups+1

-- 6. A group's top bounds only what the difficulty adds: a step the creature's own INT or an
-- override gives stays. Beetles of INT 3 and dogs of 4 stay dull on Insane; a troll whose file
-- means 10 stays normal there; Olhydra (an elemental, INT 17) is clever by her file; an override
-- makes an ogre clever, and one that makes it normal keeps it normal on Insane. Groups without a
-- top lift as before.
assert(mind.wit({general='ANIMAL',race='BEETLE',int=3,wis=3,difficulty=5}).step=='dull')
assert(mind.wit({general='ANIMAL',race='DOG',int=4,wis=4,difficulty=5}).step=='dull')
w=mind.wit({family='monster',race='TROLL',int=10,wis=14,difficulty=5})
assert(w.step=='normal' and w.from=='stats' and w.int==14)
assert(mind.wit({family='monster',race='TROLL',int=10,wis=14,difficulty=3}).step=='normal')
w=mind.wit({family='monster',race='ELEMENTAL',int=17,wis=16,difficulty=3})
assert(w.step=='clever' and w.group=='low' and w.from=='stats')
assert(mind.wit({family='monster',race='ELEMENTAL',int=17,wis=16,difficulty=5}).step=='clever')
assert(mind.wit({family='monster',race='ELEMENTAL',int=17,wis=16,difficulty=1}).step=='normal')
-- A displacer beast whose file means 8 is normal by its own INT, and stays so on Insane.
assert(mind.wit({general='ANIMAL',race='CAT',int=8,wis=8,difficulty=5}).step=='normal')
local ogres={BOSS={step='clever'},BRUTE={step='normal'}}
assert(mind.wit({resref='BOSS',race='OGRE',int=16,wis=9,difficulty=3},ogres).step=='clever')
assert(mind.wit({resref='BRUTE',race='OGRE',int=16,wis=9,difficulty=5},ogres).step=='normal')
assert(mind.wit({race='DRAGON',int=12,wis=12,difficulty=5}).step=='clever')
assert(mind.wit({race='HUMAN',int=12,wis=12,difficulty=4}).step=='clever')
groups=groups+1

-- 7. Tactics by wit (Christopher, 2026-10-25: "um ein bisschen Varianz ins Spiel zu bringen"): a
-- clever creature sees a tactic's chance always, a normal one in half its decisions, a dull one
-- never; the profile's own tactics scales that. The interrupt worth is checked like any knob.
assert(base.tactics==1 and base.interrupt==0.1)
assert(mind.withWit(base,{step='clever',danger=1}).tactics==1 and mind.withWit(base,{step='normal',danger=1}).tactics==0.5)
assert(mind.withWit(base,{step='dull',danger=1}).tactics==0)
assert(mind.withWit(mind.new({tactics=0.5}),{step='normal',danger=1}).tactics==0.25)
bad,why=mind.new({tactics=2});assert(bad==nil and why=='tactics')
bad,why=mind.new({interrupt=-1});assert(bad==nil and why=='interrupt')
groups=groups+1

-- 8. The best option by wit (Christopher, 2026-10-29: imperfect on purpose, clever groups more
-- dangerous than SCS's): the default 0.6 makes a clever creature take the best 8 times in 10, a
-- normal one 6 and a dull one 4, the base unchanged. A profile that always takes the best keeps it
-- at every step; one that never does takes it half the time when clever and never when dull. An
-- unknown step keeps the profile's own; a lab can change the shares.
assert(near(mind.withWit(base,{step='clever',danger=1}).best,0.8) and near(mind.withWit(base,{step='normal',danger=1}).best,0.6))
assert(near(mind.withWit(base,{step='dull',danger=1}).best,0.4) and base.best==0.6)
for _,step in ipairs({'clever','normal','dull'}) do
    assert(mind.withWit(mind.new({best=1}),{step=step,danger=1}).best==1)
end
assert(near(mind.withWit(mind.new({best=0}),{step='clever',danger=1}).best,0.5))
assert(mind.withWit(mind.new({best=0}),{step='dull',danger=1}).best==0)
assert(near(mind.withWit(mind.new({best=0.9}),{step='dull',danger=1}).best,0.85))
assert(near(mind.withWit(base,{step='genius',danger=1}).best,0.6))
local stray=mind.STRAY.clever;mind.STRAY.clever=0
assert(mind.withWit(base,{step='clever',danger=1}).best==1)
mind.STRAY.clever=stray
groups=groups+1

return groups
