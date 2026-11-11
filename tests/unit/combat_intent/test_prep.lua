-- SCS's preparation, phase 1 (combat-intent/prep.lua): the engine holds back SCS's first-round casts of
-- the creatures it drives and whatever their orders hold back; the rest runs as SCS has it. Plain
-- values; no game data.
local prep=require('combat-intent.prep')
local orders=require('combat-intent.orders')
local groups=0

-- 1. Without orders: openers wait, as the engine chooses the first round itself; prebuffs,
-- contingencies and chains run as SCS's; an unknown kind runs too.
assert(prep.holds('opener','WIZARD_MIRROR_IMAGE','',nil)==true and prep.holds('opener','','',{prep=true})==true)
for _,kind in ipairs({'prebuff','contingency','chain'}) do
    assert(prep.holds(kind,'dwsw408','WIZARD_STONE_SKIN',nil)==false,kind)
    assert(prep.holds(kind,'dwsw408','WIZARD_STONE_SKIN',{})==false,kind)
end
assert(prep.holds('summon','dwsw408','',nil)==false and prep.holds(nil,'','',{prep=false})==false)
groups=groups+1

-- 2. Orders: prep=false holds all of it, prep=true nothing more; prepSkip holds what it names, a kind or
-- the cast or the spent spell, in any case, but never by an empty name.
assert(prep.holds('prebuff','dwsw408','WIZARD_STONE_SKIN',{prep=false})==true)
assert(prep.holds('chain','dw#cc12','',{prep=false})==true and prep.holds('chain','dw#cc12','',{prep=true})==false)
assert(prep.holds('contingency','WIZARD_IMPROVED_INVISIBILITY','',{prepSkip={'contingency'}})==true)
assert(prep.holds('prebuff','dwsw408','',{prepSkip={'contingency','chain'}})==false)
assert(prep.holds('prebuff','dwsw408','WIZARD_STONE_SKIN',{prepSkip={'wizard_stone_skin'}})==true)
assert(prep.holds('prebuff','dwsw408','WIZARD_STONE_SKIN',{prepSkip={'DWSW408'}})==true)
assert(prep.holds('prebuff','dwsw212','WIZARD_MIRROR_IMAGE',{prepSkip={'WIZARD_STONE_SKIN','Prebuff'}})==true)
assert(prep.holds('prebuff','dwsw212','',{prepSkip={'WIZARD_STONE_SKIN'}})==false)
assert(prep.holds('prebuff','','',{prepSkip={'dwsw212'}})==false and prep.holds('prebuff',nil,nil,{prepSkip={'x'}})==false)
assert(prep.holds('prebuff','dwsw212','',{prepSkip='dwsw212'})==false)
groups=groups+1

-- 3. The orders' check takes prep (true or false) and prepSkip (a list of names as SCS's blocks write
-- spells, at most 64 characters each).
assert(orders.check({prep=false}) and orders.check({prep=true,hide=true}))
assert(orders.check({prepSkip={'contingency','WIZARD_STONE_SKIN','dw#cc12','DWSW-1'}}))
assert(select(2,orders.check({prep='no'}))=='prep' and select(2,orders.check({prepSkip={}}))=='prepSkip')
assert(select(2,orders.check({prepSkip='prebuff'}))=='prepSkip' and select(2,orders.check({prepSkip={1}}))=='prepSkip')
assert(select(2,orders.check({prepSkip={"it's"}}))=='prepSkip' and select(2,orders.check({prepSkip={'a b'}}))=='prepSkip')
assert(select(2,orders.check({prepSkip={string.rep('x',65)}}))=='prepSkip' and orders.check({prepSkip={string.rep('x',64)}}))
assert(select(2,orders.check({prepSkip={x='prebuff'}}))=='prepSkip')
groups=groups+1

-- 4. Area-scoped hold (noPrepIn, Venkt inside Tazok's tent BG1901 vs outdoor BG1900) and fight-start
-- prebuff / prebuffFrom order checks.
local venkt={noPrepIn={'BG1901','AR1901'}}
for _,kind in ipairs({'prebuff','contingency','chain'}) do
    assert(prep.holds(kind,'dwsw212','WIZARD_MIRROR_IMAGE',venkt,'bg1901')==true,kind)
    assert(prep.holds(kind,'dwsw311','WIZARD_PROTECTION_FROM_NORMAL_MISSILES',venkt,'AR1901')==true,kind)
    assert(prep.holds(kind,'dwsw212','WIZARD_MIRROR_IMAGE',venkt,'BG1900')==false,kind)
    assert(prep.holds(kind,'dwsw212','WIZARD_MIRROR_IMAGE',venkt,'')==false,kind)
    assert(prep.holds(kind,'dwsw212','WIZARD_MIRROR_IMAGE',venkt,nil)==false,kind)
end
assert(prep.holds('summon','dwsw212','',venkt,'BG1901')==false)
assert(orders.check({noPrepIn={'BG1901','AR1901'},prebuff={{cast='SPPR301',spend='SPPR301'},'buff-potion'},prebuffFrom=4}))
assert(select(2,orders.check({noPrepIn={}}))=='noPrepIn' and select(2,orders.check({noPrepIn='BG1901'}))=='noPrepIn')
assert(select(2,orders.check({noPrepIn={'TOOLONGAREA'}}))=='noPrepIn' and select(2,orders.check({noPrepIn={x='BG1901'}}))=='noPrepIn')
assert(select(2,orders.check({prebuff={}}))=='prebuff' and select(2,orders.check({prebuff='buff-potion'}))=='prebuff')
assert(select(2,orders.check({prebuff={{cast='SPPR301'}}}))=='prebuff' and select(2,orders.check({prebuff={x='buff-potion'}}))=='prebuff')
assert(select(2,orders.check({prebuff={'buff-potion'},prebuffFrom=0}))=='prebuffFrom')
assert(select(2,orders.check({prebuff={'buff-potion'},prebuffFrom=6}))=='prebuffFrom')
groups=groups+1

return groups
