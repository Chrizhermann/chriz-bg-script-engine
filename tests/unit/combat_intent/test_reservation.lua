-- Advisory only: these records never authorize an action or consume a spell.
local reservation=require('combat-intent.reservation')
local copy=require('kernel.manifest').copy
local equal=require('kernel.manifest').equal
local rng=require('kernel.rng')
local groups=0
local function bad(fn) assert(not pcall(fn),'invalid input accepted') end
local a={adapterId='B-/combat/group-a',key='mage-a',resource='MAGEA.CRE'}
local b={adapterId='B-/combat/group-b',key='mage-b',resource='MAGEB.CRE'}
local c={adapterId='B-/combat/group-c',key='mage-c',resource='MAGEC.CRE'}
local function context(tick)
    return {sceneKey='scene-1',groupKey='group-1',tick=tick,combatActive=true,
        members={a,b},targets={'enemy-a','enemy-b'},spaces={'lane-a','lane-b'}}
end
local function board(capacity)
    return reservation.new({sceneKey='scene-1',groupKey='group-1',maxEntries=capacity or 4,maxLifetimeTicks=12})
end

local r=board()
local target={kind='target',targetKey='enemy-a',expiresAt=5}
local claim=assert(r:reserve(a,target,context(0)))
assert(claim.token and claim.kind=='target' and equal(claim.owner,a) and claim.expiresAt==5)
local again=assert(r:reserve(a,{kind='target',targetKey='enemy-a',expiresAt=9},context(1)))
assert(equal(again,claim),'same-owner reservation extended or replaced')
assert(not r:reserve(b,target,context(1)))
local view=assert(r:view(b,context(1)))
assert(view.dispatchAuthorized==false and #view.claims==1 and #view.members==2)
view.claims[1].owner.key='tampered';view.targets[1]='tampered';claim.owner.key='tampered'
assert(r:view(a,context(1)).claims[1].owner.key=='mage-a')
assert(target.expiresAt==5 and a.key=='mage-a')
groups=groups+1

local eff=assert(r:reserve(b,{kind='effect',targetKey='enemy-a',effectKey='slow',expiresAt=8},context(1)))
assert(not r:reserve(a,{kind='effect',targetKey='enemy-a',effectKey='slow',expiresAt=8},context(1)))
assert(r:reserve(a,{kind='effect',targetKey='enemy-b',effectKey='slow',expiresAt=8},context(1)))
assert(r:reserve(a,{kind='effect',targetKey='enemy-a',effectKey='blind',expiresAt=8},context(1)))
assert(not r:reserve(a,{kind='space',spaceKey='lane-a',expiresAt=8},context(1))) -- capacity
assert(#r:view(a,context(1)).claims==4)
assert(not r:release(a,eff.token))
assert(r:release(b,eff.token))
assert(r:reserve(b,{kind='space',spaceKey='lane-a',expiresAt=8},context(1)))
assert(not r:reserve(a,{kind='space',spaceKey='lane-a',expiresAt=8},context(1)))
local successor=board()
local newer=assert(successor:reserve(a,target,context(0)))
assert(not successor:release(a,claim.token) and newer.token~=claim.token,'stale board token reused')
assert(#successor:view(a,context(0)).claims==1)
groups=groups+1

local expire=board()
bad(function() expire:reserve(a,{kind='target',targetKey='enemy-a',expiresAt=0},context(0)) end)
bad(function() expire:reserve(a,{kind='target',targetKey='enemy-a',expiresAt=13},context(0)) end)
assert(expire:reserve(a,{kind='target',targetKey='enemy-a',expiresAt=2},context(0)))
assert(#expire:view(a,context(1)).claims==1)
assert(#expire:view(b,context(2)).claims==0)
assert(expire:reserve(b,{kind='target',targetKey='enemy-a',expiresAt=4},context(2)))
local smaller=context(1)
assert(not expire:view(a,smaller))
assert(#expire:view(a,context(2)).claims==1)
groups=groups+1

local lost=board()
assert(lost:reserve(a,{kind='target',targetKey='enemy-a',expiresAt=9},context(0)))
assert(lost:reserve(b,{kind='space',spaceKey='lane-a',expiresAt=9},context(0)))
local removed=context(1);removed.members={b};removed.targets={'enemy-b'};removed.spaces={'lane-b'}
assert(#lost:view(b,removed).claims==0)
assert(not lost:reserve(a,{kind='target',targetKey='enemy-b',expiresAt=8},removed))
local restored=context(2)
assert(#lost:view(a,restored).claims==0,'lost reservations revived')
local invalid=context(3);invalid.targets={'enemy-a','enemy-a'}
bad(function() lost:view(a,invalid) end)
assert(#lost:view(a,restored).claims==0,'invalid context mutated board')
local whole=board()
assert(whole:reserve(a,target,context(0)))
local duplicate=context(1);duplicate.members={a,copy(a)}
bad(function() whole:view(a,duplicate) end)
assert(#whole:view(a,context(0)).claims==1,'invalid membership partially reaped')
groups=groups+1

local ending=board()
assert(ending:reserve(a,{kind='target',targetKey='enemy-a',expiresAt=9},context(0)))
local scene=context(1);scene.sceneKey='scene-2'
assert(not ending:view(a,scene) and not ending:reserve(a,target,context(2)))
local regroup=board();assert(regroup:reserve(a,target,context(0)))
local changedGroup=context(1);changedGroup.groupKey='group-2'
assert(not regroup:view(a,changedGroup) and not regroup:view(a,context(2)))
local disabled=board();assert(disabled:reserve(a,target,context(0)))
disabled:invalidate('adapter-disabled');assert(not disabled:view(a,context(1)))
local finished=board();assert(finished:reserve(a,target,context(0)))
local ended=context(1);ended.combatActive=false
assert(not finished:view(a,ended) and not finished:view(a,context(2)))
bad(function() board(257) end)
bad(function() board(0) end)
assert(not board():reserve(c,target,context(0))) -- absent owner is refused
groups=groups+1

-- Same seeded interleavings always produce the same exclusive/advisory state.
local function run(seed)
    local sim=board(2);local random=rng.new(seed);local sequence={}
    for tick=0,8 do
        local owner=random:nextInt(1,2)==1 and a or b
        local key=random:nextInt(1,2)==1 and 'enemy-a' or 'enemy-b'
        local result,why=sim:reserve(owner,{kind='target',targetKey=key,expiresAt=tick+2},context(tick))
        sequence[#sequence+1]={tick=tick,owner=owner.key,key=key,result=result and 'claimed' or why,
            count=#assert(sim:view(a,context(tick))).claims}
        local claims=sim:view(b,context(tick)).claims
        assert(#claims<=2)
        for i=1,#claims do for j=i+1,#claims do
            assert(claims[i].targetKey~=claims[j].targetKey,'duplicate exclusive target')
        end end
    end
    return sequence
end
assert(equal(run(17),run(17)) and equal(run(29),run(29)))
groups=groups+1
return groups
