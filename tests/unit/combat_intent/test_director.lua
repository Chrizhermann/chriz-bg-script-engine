-- The fight director on plain frames: shared picture, focus target, one disabler per target,
-- advice on a member's starting cast, outcomes and the log. No game data.
local director=require('combat-intent.director')
local spells=require('combat-intent.spells')
local groups=0

local function fx(op,fields)
    local e={opcode=op,target=2,power=0,p1=0,p2=0,timing=0,resist=1,duration=0,prob1=100,prob2=0,
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
-- An enemy its minimum hit points (opcode 208) keep where it is looks nearly dead and cannot
-- die: it is no focus, and the focus moves off one that reaches its minimum (lab batch H9).
-- Above it, the most wounded is the one with the least above its minimum.
local floored=director.new({})
floored:checkIn(mage,frame(5,nil,{enemy(11,{hp=1,minHp=1}),enemy(12,{hp=15})}))
assert(floored:focus(5)==12)
local rage=director.new({})
rage:checkIn(mage,frame(5,nil,{enemy(11,{hp=8,minHp=6}),enemy(12,{hp=5})}))
assert(rage:focus(5)==11)
rage:checkIn(mage,frame(6,nil,{enemy(11,{hp=6,minHp=6}),enemy(12,{hp=5})}))
assert(rage:focus(6)==12)
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
-- Every family's casts are advised (F1e); a director told to leave a family alone keeps them.
d:checkIn(fighter,frame(40,nil,{enemy(11)}))
a=d:advise(fighter,f,bolt,11,40)
assert(a.action=='redirect' and a.target==12 and a.reason=='focus')
local casters=director.new({families={mage=true,priest=true}})
casters:checkIn(fighter,frame(40,nil,{enemy(11)}))
assert(casters:advise(fighter,f,bolt,11,40).reason=='family')
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

-- 7. A cast its script aimed at a kind of creature takes any legal target like any other cast,
-- a creature of another kind too; the log marks it.
local function kinOf(id,class,fields) local e=enemy(id,fields);e.ids={ea=2,general=1,class=class};return e end
local kd=director.new({})
f=frame(700,nil,{kinOf(11,1,{held=1}),kinOf(12,2),kinOf(13,1)})
kd:checkIn(mage,f)
-- 12 is no mage like 11, and the nearest free enemy.
a=kd:advise(mage,f,hold,11,700,true)
assert(a.action=='redirect' and a.target==12 and kd:inspect().log[#kd:inspect().log].typed==true)
assert(kd:advise(mage,f,hold,11,700).target==12 and kd:inspect().log[#kd:inspect().log].typed==nil)
local kf=director.new({})
f=frame(702,nil,{kinOf(11,1),kinOf(12,2,{hp=5})})
kf:checkIn(mage,f)
a=kf:advise(mage,f,bolt,11,702,true)
assert(a.action=='redirect' and a.target==12 and a.reason=='focus')
kf:started(mage,{spell='TESTHOLD',role='disable',target=11,original=11,typed=true},703)
assert(kf:inspect().log[#kf:inspect().log].typed==true and kf:inspect().reservations[1].target==11)
-- The group's picture: when each enemy was last seen, by how many, whether disabled.
local known=kd:inspect().known
assert(#known==3 and known[1].id==11 and known[1].disabled==true and known[2].seenBy==1 and known[3].lastTick==700)
groups=groups+1

-- 8. The focus lapses a round after no member has seen it, or when it dies; the loss is logged.
local lost={}
local fl=director.new({sink=function(row) lost[#lost+1]=row end})
fl:checkIn(mage,frame(10,nil,{enemy(11)}))
assert(fl:focus(10)==11)
fl:tick(100)
assert(fl:inspect().focus==11)
fl:tick(101)
s=fl:inspect()
assert(s.focus==nil and s.counts.focusLost==1 and lost[#lost].kind=='focus' and lost[#lost].previous==11)
assert(lost[#lost].why=='unseen' and lost[#lost].target==nil)
fl:checkIn(mage,frame(110,nil,{enemy(12)}))
assert(fl:focus(110)==12)
fl:checkIn(mage,frame(111,nil,{enemy(12,{hp=0,state=0x800})}))
fl:tick(111)
assert(lost[#lost].why=='dead' and lost[#lost].previous==12 and fl:inspect().counts.focusLost==2)
groups=groups+1

-- 9. The engine's own disable claims its targets once chosen, before its cast is queued: the
-- claim keeps other members off for claimTicks at most and gives way to the cast's start,
-- which reserves every enemy its area hits until the cast ends (and graceTicks after); a
-- decision given up releases its claims. Nobody takes a target another member holds.
local function three() return {enemy(11),enemy(12),enemy(13)} end
local cd=director.new({})
cd:checkIn(mage,frame(10,nil,three()))
cd:checkIn(priest,frame(10,{x=300},three()))
assert(cd:reserve(mage,{11,12},10)==2)
local plan=cd:plan(10)
assert(plan.reserved[11]==1 and plan.reserved[12]==1 and plan.reserved[13]==nil)
s=cd:inspect()
local reserve
for _,row in ipairs(s.log) do if row.kind=='reserve' then reserve=row end end
assert(#s.reservations==2 and s.reservations[1].claim==true and reserve.member==1 and #reserve.targets==2)
-- The priest's own cast at 11 gives way to the free 13.
p=frame(12,{x=300},three())
cd:checkIn(priest,p)
a=cd:advise(priest,p,hold,11,12)
assert(a.action=='redirect' and a.target==13 and a.reason=='reserved')
-- The priest cannot claim what the mage holds; claims lapse after claimTicks.
assert(cd:reserve(priest,{11,13},12)==1 and cd:plan(12).reserved[13]==2 and cd:plan(12).reserved[11]==1)
assert(cd:plan(69).reserved[11]==1 and cd:plan(70).reserved[11]==nil and cd:plan(70).reserved[13]==2)
-- The mage's area disable starts: it reserves both enemies it hits, as a cast, not a claim.
assert(cd:reserve(mage,{11},80)==1)
cd:started(mage,{spell='TESTHOLD',role='disable',target=11,hits={11,12},original=11,own=true},85)
plan=cd:plan(85)
assert(plan.reserved[11]==1 and plan.reserved[12]==1)
for _,r in ipairs(cd:inspect().reservations) do
    if r.owner==1 then assert(r.claim==nil and r.untilTick==85+225) end
end
-- Its end frees both graceTicks later.
cd:action(1,100)
assert(cd:plan(129).reserved[12]==1 and cd:plan(130).reserved[11]==nil and cd:plan(130).reserved[12]==nil)
-- A decision given up releases its claims, never the member's cast reservations; a claim does
-- not shorten them either; a started cast replaces the member's claims.
cd:started(mage,{spell='TESTHOLD',role='disable',target=12,original=12,own=true},150)
assert(cd:reserve(mage,{11,12},151)==2 and cd:release(mage,152)==1)
plan=cd:plan(152)
local released
for _,row in ipairs(cd:inspect().log) do if row.kind=='release' then released=row end end
assert(plan.reserved[12]==1 and plan.reserved[11]==nil and released.member==1 and released.count==1)
for _,r in ipairs(cd:inspect().reservations) do
    if r.target==12 then assert(r.claim==nil and r.untilTick==150+225) end
end
assert(cd:release(mage,153)==0)
-- A new claim replaces the member's earlier ones.
assert(cd:reserve(mage,{11},155)==1 and cd:reserve(mage,{13},156)==1)
plan=cd:plan(156)
assert(plan.reserved[11]==nil and plan.reserved[13]==1 and plan.reserved[12]==1)
assert(cd:reserve(mage,{13},160)==1)
cd:started(mage,{spell='TESTBOLT',role='damage',target=13,original=13,own=true},161)
assert(cd:plan(161).reserved[13]==nil)
-- A started disable leaves an enemy another member holds to it.
local ns=director.new({})
ns:checkIn(mage,frame(10,nil,three()))
ns:checkIn(priest,frame(10,{x=300},three()))
ns:started(priest,{spell='TESTHOLD',role='disable',target=11,original=11},10)
ns:started(mage,{spell='TESTHOLD',role='disable',target=11,hits={11,12},original=11,own=true},11)
plan=ns:plan(11)
assert(plan.reserved[11]==2 and plan.reserved[12]==1)
assert(cd:reserve({id=-1},{11},170)==0 and cd:reserve(mage,nil,170)==0 and cd:release(nil,170)==0)
groups=groups+1

-- 10. Clues for the engine's search (combat-intent/search.lua): where the group last saw each living
-- enemy, when, by whom and which way it went: from two sightings at least headingMin ticks apart,
-- none after a gap of more than headingTicks. A dead enemy is no clue. The members, by id.
local sd=director.new({})
sd:checkIn(mage,frame(100,nil,{enemy(11,{x=100,y=0}),enemy(12)}))
sd:checkIn(priest,frame(102,{x=300},{enemy(11,{x=104,y=0})}))
sd:checkIn(mage,frame(115,nil,{enemy(11,{x=130,y=30})}))
local list=sd:clues(fighter.id,120)
assert(#list==2 and list[1].id==11 and list[2].id==12)
assert(list[1].x==130 and list[1].y==30 and list[1].tick==115 and list[1].by==true)
-- 15 ticks, a second, from (100, 0) to (130, 30): the sighting two ticks after the first was too soon.
assert(list[1].vx==30 and list[1].vy==30 and list[2].vx==nil and list[2].tick==100)
-- The mage saw 11 last itself: no other member did then.
assert(sd:clues(mage.id,120)[1].by==false and sd:clues(priest.id,120)[1].by==true)
-- Seen again after a long gap: no heading until a second sighting.
sd:checkIn(priest,frame(200,{x=300},{enemy(11,{x=400,y=0})}))
assert(sd:clues(mage.id,200)[1].vx==nil)
sd:checkIn(priest,frame(205,{x=300},{enemy(11,{x=410,y=0})}))
assert(sd:clues(mage.id,205)[1].vx==30)
sd:checkIn(priest,frame(210,{x=300},{enemy(12,{hp=0,state=0x800})}))
list=sd:clues(mage.id,210)
assert(#list==1 and list[1].id==11)
local members=sd:members(210)
assert(#members==2 and members[1].id==1 and members[1].family=='mage' and members[2].id==2 and members[2].x==300)
assert(#sd:members(400)==0)
groups=groups+1

return groups
