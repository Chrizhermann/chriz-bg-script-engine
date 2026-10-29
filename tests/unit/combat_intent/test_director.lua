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

-- 11. Debuffs (F2b): the engine's own debuff claims the enemies it weakens for its spell, so that
-- another member leaves that spell off them, not other ones; claims lapse after claimTicks and a
-- member's new decision replaces its earlier claims. Its cast's start holds them until it ends and
-- graceTicks after; a decision given up releases them. A disable and a debuff never block each
-- other.
local kd=director.new({})
kd:checkIn(mage,frame(10,nil,three()))
kd:checkIn(priest,frame(10,{x=300},three()))
assert(kd:curse(priest,{11,12},'TESTDOOM',10)==2)
plan=kd:plan(10)
assert(plan.cursed[11].TESTDOOM==2 and plan.cursed[12].TESTDOOM==2 and plan.cursed[13]==nil and next(plan.reserved)==nil)
local cursed
for _,row in ipairs(kd:inspect().log) do if row.kind=='curse' then cursed=row end end
assert(cursed.member==2 and cursed.spell=='TESTDOOM' and #cursed.targets==2)
assert(kd:curse(mage,{11,13},'TESTDOOM',11)==1 and kd:plan(11).cursed[13].TESTDOOM==1)
assert(kd:curse(mage,{11},'TESTSLOW',12)==1)
plan=kd:plan(12)
assert(plan.cursed[11].TESTSLOW==1 and plan.cursed[11].TESTDOOM==2 and plan.cursed[13]==nil)
assert(kd:reserve(mage,{11},13)==1)
plan=kd:plan(13)
assert(plan.reserved[11]==1 and plan.cursed[11].TESTDOOM==2 and plan.cursed[11].TESTSLOW==nil)
assert(kd:plan(69).cursed[11].TESTDOOM==2 and kd:plan(70).cursed[11]==nil)
kd:started(priest,{spell='TESTDOOM',role='debuff',target=11,hits={11},original=11,own=true},80)
assert(kd:plan(80).cursed[11].TESTDOOM==2)
local held=kd:inspect().curses
assert(#held==1 and held[1].target==11 and held[1].claim==nil and held[1].untilTick==80+225)
kd:action(2,100)
assert(kd:plan(129).cursed[11].TESTDOOM==2 and kd:plan(130).cursed[11]==nil)
assert(kd:curse(priest,{12},'TESTDOOM',140)==1 and kd:release(priest,141)==1 and kd:plan(141).cursed[12]==nil)
assert(kd:curse(mage,{11},nil,150)==0 and kd:curse({id=-1},{11},'TESTDOOM',150)==0 and kd:curse(mage,nil,'TESTDOOM',150)==0)
groups=groups+1

-- 12. Foes out of play (lab batch J; Christopher, 2026-10-29). One the group charmed stands among
-- its allies (seen as an enemy before, or one of the party): it leaves the picture, no clue and no
-- focus, until it shows as an enemy again. One no member has seen for removalTicks is checked for a
-- maze or a prison, each at most once in removalTicks: a mazed one is held where it vanished until
-- the maze ends, then seen there afresh; an imprisoned one is forgotten; one gone ends its maze.
-- Records lapse unseen after awayTicks, any after awaitTicks.
local od=director.new({})
local function thrall(id,fields)
    local a={id=id,x=100*(id-10),y=0,state=0x2000,hp=20,maxHp=20}
    for k,v in pairs(fields or {}) do a[k]=v end
    return a
end
local function logged(dd,kind)
    local out={}
    for _,row in ipairs(dd:inspect().log) do if row.kind==kind then out[#out+1]=row end end
    return out
end
local function clueIds(dd,tick)
    local out={}
    for _,c in ipairs(dd:clues(fighter.id,tick)) do out[#out+1]=c.id end
    return table.concat(out,',')
end
od:checkIn(mage,frame(10,nil,{enemy(11),enemy(12),enemy(13)}))
assert(od:focus(10)==11)
local cf=frame(20,nil,{enemy(12),enemy(13)})
cf.allies={thrall(11),thrall(14),thrall(15,{player=2}),thrall(16,{state=0})}
od:checkIn(mage,cf)
local out=od:away(20)
assert(#out==2 and out[1].id==11 and out[1].kind=='charm' and out[1].x==100 and out[1].since==20 and out[1].lastTick==20)
assert(out[2].id==15 and out[2].kind=='charm' and out[2].x==500)
assert(clueIds(od,20)=='12,13')
od:tick(20)
local lost=logged(od,'focus')
assert(lost[#lost].previous==11 and lost[#lost].why=='away' and od:focus(20)==12)
local aw=logged(od,'away')
assert(#aw==2 and aw[1].target==11 and aw[1].away=='charm')
-- The plan's foes in play leave them out too (combat-intent/choice.lua: no charm or maze on the
-- last foe in play), and the dead.
local function inPlay(dd,tick)
    local out={}
    for key in pairs(dd:plan(tick).inPlay) do out[#out+1]=key end
    table.sort(out)
    return table.concat(out,',')
end
assert(inPlay(od,20)=='12,13')
local dead=director.new({})
dead:checkIn(mage,frame(10,nil,{enemy(21,{hp=0,state=0x800}),enemy(22)}))
assert(inPlay(dead,10)=='22')
-- The charm ends: an enemy again.
od:checkIn(mage,frame(30,nil,{enemy(11),enemy(12),enemy(13)}))
out=od:away(30)
assert(#out==1 and out[1].id==15)
local backs=logged(od,'back')
assert(#backs==1 and backs[1].target==11 and backs[1].away=='charm' and backs[1].ticks==10)
-- 12 vanishes into a maze: checked once it is 15 ticks unseen, held where it stands, checked again
-- each 15 ticks.
od:checkIn(mage,frame(40,nil,{enemy(11),enemy(13)}))
assert(#od:removalChecks(40)==0)
od:checkIn(mage,frame(45,nil,{enemy(11),enemy(13)}))
local checks=od:removalChecks(45)
assert(#checks==1 and checks[1]==12)
od:removed(12,'maze',{x=210,y=5},45)
assert(#od:removalChecks(46)==0)
out=od:away(46)
assert(#out==2 and out[1].id==12 and out[1].kind=='maze' and out[1].x==210 and out[1].y==5 and out[2].id==15)
assert(clueIds(od,46)=='11,13' and inPlay(od,46)=='11,13')
od:checkIn(mage,frame(60,nil,{enemy(11),enemy(13)}))
checks=od:removalChecks(60)
assert(#checks==1 and checks[1]==12)
od:removed(12,'maze',{x=210,y=5},60)
assert(#od:removalChecks(74)==0)
-- Out again, still unseen: a fresh sighting where it vanished.
od:checkIn(mage,frame(75,nil,{enemy(11),enemy(13)}))
checks=od:removalChecks(75)
assert(#checks==1 and checks[1]==12)
od:removed(12,nil,{x=210,y=5},75)
out=od:away(75)
assert(#out==1 and out[1].id==15)
local c12
for _,c in ipairs(od:clues(fighter.id,75)) do if c.id==12 then c12=c end end
assert(c12 and c12.x==210 and c12.y==5 and c12.tick==75 and c12.by==false)
-- 13 imprisoned: forgotten at once, nothing to await.
od:checkIn(mage,frame(80,nil,{enemy(11)}))
od:checkIn(mage,frame(95,nil,{enemy(11)}))
checks=od:removalChecks(95)
assert(#checks==2 and checks[1]==12 and checks[2]==13)
od:removed(12,nil,{x=210,y=5},95)
od:removed(13,'prison',{x=300,y=0},95)
assert(clueIds(od,95)=='11,12' and #od:away(95)==1)
aw=logged(od,'away')
assert(aw[#aw].target==13 and aw[#aw].away=='prison' and aw[#aw].x==300)
-- Unseen for awayTicks: 15's record lapses.
od:tick(470)
assert(#od:away(470)==1)
od:tick(471)
assert(#od:away(471)==0)
local ends=logged(od,'away-end')
assert(#ends==1 and ends[1].target==15 and ends[1].why=='unseen' and ends[1].away=='charm')
local info=od:inspect()
assert(info.foes==3 and info.counts.away==4 and info.counts.back==2 and info.counts.awayEnded==1 and #info.away==0)
-- Kept up for awaitTicks at most; one gone (dead, left) ends its maze; odd input changes nothing.
local wd=director.new({awaitTicks=100})
wd:checkIn(mage,frame(10,nil,{enemy(11)}))
wd:removed(11,'maze',{x=100,y=0},30)
for t=45,105,15 do wd:removed(11,'maze',{x=100,y=0},t) end
wd:tick(130)
assert(#wd:away(130)==1)
wd:tick(131)
assert(#wd:away(131)==0 and logged(wd,'away-end')[1].why=='await')
wd:removed(11,'maze',{x=100,y=0},140)
wd:removed(11,nil,nil,150)
assert(#wd:away(150)==0 and #wd:clues(fighter.id,150)==0 and logged(wd,'away-end')[2].why=='gone')
wd:removed('x','maze',{x=1,y=1},160)
wd:removed(12,'maze',nil,160)
wd:removed(12,'maze',{x='a',y=1},160)
assert(#wd:away(160)==0)
wd:removed(12,'maze',{x=1,y=1},160)
assert(#wd:away(160)==1)
wd:invalidate('test')
assert(#wd:away(170)==0 and wd:inspect().foes==0)
groups=groups+1

return groups
