-- The fight director on plain frames: shared picture, focus target, one disabler per target,
-- advice on a member's starting cast, outcomes and the log. No game data.
local director=require('combat-intent.director')
local spells=require('combat-intent.spells')
local groups=0

local function fx(op,fields)
    local e={opcode=op,target=2,power=0,p1=0,p2=0,timing=0,resist=0,duration=0,prob1=100,prob2=0,
        res='',dice=0,sides=0,save=0,saveBonus=0,special=0}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function spell(resref,effects,ability)
    local a={form=1,flags=0,location=2,target=1,targetCount=0,range=30,minLevel=1,speed=3,projectile=2,effects=effects}
    for k,v in pairs(ability or {}) do a[k]=v end
    local r={kind='SPL',resref=resref,name=0,flags=1024,spellType=1,exclusion=0,school=0,secondary=0,
        level=3,abilities={a},casting={}}
    local single={kind='PRO',resref='SINGLE',type=2,speed=20,flags=0,extFlags=0}
    return spells.classify(r,1,function(kind,key) if kind=='PRO' and key==2 then return single end end,{level=10})
end
local bolt=spell('TESTBOLT',{fx(12,{dice=6,sides=6})})
local hold=spell('TESTHOLD',{fx(175,{duration=30})})
local ball=spell('TESTBALL',{fx(12,{dice=6,sides=6})},{target=4})

-- Enemies 11, 12 and 13 stand in a row; members 1 and 2 (mage, priest) and 3 (fighter).
local function enemy(id,fields)
    local e={id=id,x=100*(id-10),y=0,state=0,held=0,hp=20,maxHp=20,mr=0,ids={general=1},protections={},action=0}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function frame(tick,self,enemies)
    local s={x=0,y=0,action=0};for k,v in pairs(self or {}) do s[k]=v end
    return {tick=tick,area='AR0001',self=s,enemies=enemies or {},allies={}}
end
local mage,priest,fighter={id=1,family='mage'},{id=2,family='priest'},{id=3,family='fighter'}
local rows={}
local d=director.new({area='AR0001',sink=function(row) rows[#rows+1]=row end})

-- 1. Focus: the enemy most members see, then the most wounded, then the nearest. It stays
-- while it lives and someone sees it.
assert(d:focus(10)==nil and not d:isMember(1))
assert(d:checkIn(mage,frame(10,nil,{enemy(11),enemy(12),enemy(13)})))
assert(d:checkIn(priest,frame(10,{x=300},{enemy(12),enemy(13,{hp=10})})))
assert(d:isMember(1) and d:isMember(2) and not d:checkIn(mage,{tick=10}))
assert(d:focus(10)==13)
d:checkIn(mage,frame(20,nil,{enemy(11),enemy(12),enemy(13,{hp=10})}))
d:checkIn(priest,frame(20,{x=300},{enemy(12,{hp=5}),enemy(13,{hp=10})}))
assert(d:focus(20)==13)
-- 13 dies: 12 (seen by both, most wounded) takes over.
d:checkIn(mage,frame(30,nil,{enemy(11),enemy(12,{hp=5}),enemy(13,{hp=0,state=0x800})}))
assert(d:focus(30)==12)
-- Ties fall to the nearest, then to the lower number.
local near=director.new({})
near:checkIn(mage,frame(5,{x=250},{enemy(11),enemy(12),enemy(13)}))
assert(near:focus(5)==12)
local tie=director.new({})
tie:checkIn(mage,frame(5,{x=200},{enemy(11),enemy(13)}))
assert(tie:focus(5)==11)
groups=groups+1

-- 2. Damage goes to the focus when the focus is a legal target, else the cast stays.
local f=frame(40,nil,{enemy(11),enemy(12,{hp=5}),enemy(13,{hp=0,state=0x800})})
d:checkIn(mage,f)
local a=d:advise(mage,f,bolt,11,40)
assert(a.action=='redirect' and a.target==12 and a.kind=='damage' and a.reason=='focus')
assert(d:advise(mage,f,bolt,12,40).reason=='on-focus')
assert(d:advise(mage,frame(40,nil,{enemy(11,{action=31}),enemy(12,{hp=5})}),bolt,11,40).reason=='original-casting')
assert(d:advise(mage,frame(40,nil,{enemy(11,{hp=2}),enemy(12,{hp=5})}),bolt,11,40).reason=='original-more-wounded')
assert(d:advise(mage,frame(40,nil,{enemy(11),enemy(12,{hp=5,mr=50})}),bolt,11,40).reason=='focus-magic-resistance')
assert(d:advise(mage,frame(40,nil,{enemy(11)}),bolt,11,40).reason=='focus-unseen')
assert(d:advise(mage,f,bolt,99,40).reason=='original-unseen')
assert(d:advise(mage,f,ball,11,40).reason=='not-creature-target')
d:checkIn(fighter,frame(40,nil,{enemy(11)}))
assert(d:advise(fighter,f,bolt,11,40).reason=='family')
groups=groups+1

-- 3. One disabler per target: a free target is kept; a disabled or reserved one gives way
-- to the focus if it can take the spell, else to the nearest free enemy.
f=frame(50,nil,{enemy(11),enemy(12,{hp=5}),enemy(14,{x=150})})
d:checkIn(mage,f)
assert(d:advise(mage,f,hold,11,50).reason=='free')
d:started(mage,{spell='TESTHOLD',role='disable',target=11,original=11},50)
local p=frame(51,{x=300},{enemy(11),enemy(12,{hp=5}),enemy(14,{x=150})})
d:checkIn(priest,p)
a=d:advise(priest,p,hold,11,51)
assert(a.action=='redirect' and a.target==12 and a.reason=='reserved')
-- The reserving member itself is not blocked by its own reservation.
assert(d:advise(mage,f,hold,11,51).reason=='free')
-- The focus already disabled: the nearest free enemy instead.
p=frame(52,{x=300},{enemy(11),enemy(12,{hp=5,held=1}),enemy(14,{x=150})})
d:checkIn(priest,p)
a=d:advise(priest,p,hold,11,52)
assert(a.action=='redirect' and a.target==14)
p=frame(53,{x=300},{enemy(11,{state=0x8}),enemy(12,{hp=5,held=1})})
assert(d:advise(priest,p,hold,11,53).reason=='disabled-no-alternative')
groups=groups+1

-- 4. A reservation ends a little after its cast: when the member starts its next action or is
-- seen doing something else; it also lapses when the member leaves the group.
d:checkIn(mage,frame(60,{action=31},{enemy(11)}))
assert(d:inspect().reservations[1].target==11)
d:action(1,70)
d:tick(99)
assert(#d:inspect().reservations==1)
d:tick(100)
assert(#d:inspect().reservations==0)
d:started(mage,{spell='TESTHOLD',role='disable',target=11,original=11},110)
d:checkIn(mage,frame(120,{action=3},{enemy(11)}))
d:tick(150)
assert(#d:inspect().reservations==0)
d:started(mage,{spell='TESTHOLD',role='disable',target=11,original=11},160)
d:tick(160+151)
assert(not d:isMember(1) and #d:inspect().reservations==0)
groups=groups+1

-- 5. The log and the sink see focus changes, advice, starts and ends; a failing sink is
-- counted, never raised.
local kinds={}
for _,row in ipairs(rows) do kinds[row.kind]=(kinds[row.kind] or 0)+1 end
assert(kinds.focus>=2 and kinds.redirect>=3 and kinds.keep>=5 and kinds.start==3 and kinds['end']>=2)
local ended
for _,row in ipairs(rows) do if row.kind=='end' then ended=row end end
assert(ended.member==1 and ended.target==11 and ended.area=='AR0001')
local s=d:inspect()
assert(s.counts.redirects>=3 and s.counts.attempts==3 and #s.log==#rows)
local loud=director.new({sink=function() error('full disk') end})
loud:checkIn(mage,frame(1,nil,{enemy(11)}))
assert(loud:focus(1)==11 and loud:inspect().counts.sinkErrors==1)
groups=groups+1

-- 6. Time running backwards (a load) clears everything; so does invalidate().
local back=director.new({})
back:checkIn(mage,frame(500,nil,{enemy(11)}))
back:started(mage,{spell='TESTHOLD',role='disable',target=11,original=11},500)
back:checkIn(priest,frame(20,nil,{enemy(12)}))
s=back:inspect()
assert(s.members==1 and s.enemies==1 and #s.reservations==0)
back:invalidate('load')
s=back:inspect()
assert(s.members==0 and s.enemies==0 and s.focus==nil and s.log[#s.log].kind=='invalidated')
groups=groups+1

return groups
