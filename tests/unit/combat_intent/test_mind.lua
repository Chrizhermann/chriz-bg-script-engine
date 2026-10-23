-- Profiles and wit (combat-intent/mind.lua): kinds, meant stats, the difficulty shift, overrides
-- and the profile a wit makes. No game data.
local mind=require('combat-intent.mind')
local groups=0
local function near(a,b) return math.abs(a-b)<1e-9 end

-- 1. Kinds: casters clever; animals, animated weapons, zombies, golems and the like dull, by any
-- of GENERAL, RACE or CLASS; everyone else normal.
assert(mind.kind({family='mage',general=2})=='clever' and mind.kind({family='priest'})=='clever')
assert(mind.kind({family='monster',general=2})=='dull' and mind.kind({general=101})=='dull')
assert(mind.kind({general=4,race=148})=='dull' and mind.kind({general=1,race=109})=='dull')
assert(mind.kind({general=5,race=144})=='dull' and mind.kind({general=4,class=134})=='dull')
assert(mind.kind({general=255,race=119})=='dull' and mind.kind({general=255,class=215})=='dull')
assert(mind.kind({general=255,race=104})=='dull' and mind.kind({general=255,race=101})=='dull')
-- A troll filed as a monster, an umber hulk, a vampire, a giant and a man are normal.
assert(mind.kind({family='monster',general=255,race=124})=='normal' and mind.kind({general=4,race=0})=='normal')
assert(mind.kind({general=5})=='normal' and mind.kind({family='fighter',general=1,race=1})=='normal')
assert(mind.kind({})=='normal')
groups=groups+1

-- 2. Meant stats: template pairs and an unset INT say nothing.
assert(not mind.meant(9,9) and not mind.meant(16,9) and not mind.meant(0,12) and not mind.meant(nil,9))
assert(mind.meant(7,7) and mind.meant(9,12) and mind.meant(16,16) and mind.meant(3,9))
assert(mind.step(5)=='dull' and mind.step(6)=='normal' and mind.step(13)=='normal' and mind.step(14)=='clever')
groups=groups+1

-- 3. Wit: the kind where the file says nothing, else its INT; WIS sets the danger weight; the
-- difficulty shifts both by two a step from Normal.
local wolf={family='monster',general=2,int=9,wis=9,difficulty=3}
local w=mind.wit(wolf)
assert(w.step=='dull' and w.from=='kind' and w.int==1 and near(w.danger,1))
-- Really dull creatures stay dull on Insane, though they take harm more seriously there.
wolf.difficulty=5;w=mind.wit(wolf)
assert(w.step=='dull' and w.int==5 and w.wis==14 and near(w.danger,1.2))
-- An ettin (7/7) is normal and careless; one of INT 5 is dull on Normal and normal on Insane.
w=mind.wit({family='fighter',general=5,int=7,wis=7,difficulty=3})
assert(w.step=='normal' and w.from=='stats' and near(w.danger,0.85))
assert(mind.wit({general=5,int=5,wis=7,difficulty=3}).step=='dull')
assert(mind.wit({general=5,int=5,wis=7,difficulty=5}).step=='normal')
-- An ogre with the template 16/9 is normal, and clever on Insane.
w=mind.wit({family='fighter',general=5,int=16,wis=9,difficulty=3})
assert(w.step=='normal' and w.from=='kind' and w.int==10 and near(w.danger,1))
assert(mind.wit({family='fighter',general=5,int=16,wis=9,difficulty=5}).step=='clever')
-- A mage with 9 in every stat is clever, and normal on the easiest setting; a priest of INT 10
-- and WIS 17 is normal and careful; a mind flayer of INT 18 is clever.
assert(mind.wit({family='mage',general=1,int=9,wis=9,difficulty=3}).step=='clever')
assert(mind.wit({family='mage',general=1,int=9,wis=9,difficulty=1}).step=='normal')
w=mind.wit({family='priest',general=1,int=10,wis=17,difficulty=3})
assert(w.step=='normal' and near(w.danger,1.35))
assert(mind.wit({family='monster',general=255,int=18,wis=15,difficulty=3}).step=='clever')
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

return groups
