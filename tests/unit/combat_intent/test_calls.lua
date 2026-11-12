-- Creature-type calls for help and rate-limited overhead flair shouts (combat-intent/calls.lua).
-- Plain values only; includes actual BG2300 Friendly Arm Inn Hobgoblin pack coordinates.
local calls=require('combat-intent.calls')
local orders=require('combat-intent.orders')
local groups=0

-- 1. Creature-type profiles: mindless undead, constructs, oozes and solitary monsters stay silent;
-- wolves/dogs/worgs use same-race pack howls; intelligent humanoids and Liches/Vampires use warband
-- calls; designer orders.call overrides any default.
do
    assert(calls.profileOf({general='UNDEAD',race='SKELETON'})=='silent')
    assert(calls.profileOf({general='UNDEAD',race='ZOMBIE'})=='silent')
    assert(calls.profileOf({general='UNDEAD',race='GHOUL'})=='silent')
    assert(calls.profileOf({general='MONSTER',race='GOLEM'})=='silent')
    assert(calls.profileOf({general='MONSTER',race='SPIDER'})=='silent')
    assert(calls.profileOf({general='MONSTER',race='ANKHEG'})=='silent')
    assert(calls.profileOf({general='ANIMAL',race='WOLF'})=='pack')
    assert(calls.profileOf({general='MONSTER',race='WORG'})=='pack')
    assert(calls.profileOf({general='HUMANOID',race='HOBGOBLIN'})=='warband')
    assert(calls.profileOf({general='HUMANOID',race='HUMAN'})=='warband')
    assert(calls.profileOf({general='HUMANOID',race='GNOLL'})=='warband')
    assert(calls.profileOf({general='UNDEAD',race='LICH'})=='warband')
    assert(calls.profileOf({general='UNDEAD',race='VAMPIRE'})=='warband')
    assert(calls.profileOf({general='UNDEAD',race='SKELETON'},{call='map'})=='map')
    assert(calls.profileOf({general='HUMANOID',race='HUMAN'},{call='silent'})=='silent')

    assert(orders.check({call='silent'}) and orders.check({call='pack'}))
    assert(orders.check({call='warband'}) and orders.check({call='map'}))
    assert(select(2,orders.check({call='telepathy'}))=='call' and select(2,orders.check({call=true}))=='call')
end
groups=groups+1

-- 2. Open-map earshot & hop bounds: BG2300 Hobgoblin packs at (660,1236), (2442,339) and (4481,314)
-- never pull across the map; Hard/Insane allows 1 relay hop within earshot while Core allows 0 hops.
do
    local tracker=calls.new()
    local roster={
        {id=1,x=660,y=1236,race='HOBGOBLIN',general='HUMANOID'},
        {id=2,x=710,y=1250,race='HOBGOBLIN',general='HUMANOID'},
        {id=3,x=2442,y=339,race='HOBGOBLIN',general='HUMANOID'},
        {id=4,x=4481,y=314,race='HOBGOBLIN',general='HUMANOID'},
    }
    local ev=tracker:call(roster[1],roster,5,100,function() return 0.5 end)
    assert(#ev.alerted==1 and ev.alerted[1]==2)
    assert(#ev.shouts==1 and ev.shouts[1].id==1 and type(ev.shouts[1].text)=='string')

    -- Relay hop test: A at 0, B at 750 (outside Core 700, within Hard/Insane 800/850), C at 1450 (700 from B, within relay 85%=722), D at 2200.
    -- Core (diff 3): radius 700, maxHops 0 -> nobody at 750 reached.
    -- Insane (diff 5): radius 850, maxHops 1 -> A reaches B (hop 0) and B relays once to C (hop 1), stopping before D!
    local chain={
        {id=10,x=0,y=0,race='HUMAN',general='HUMANOID'},
        {id=11,x=750,y=0,race='HUMAN',general='HUMANOID'},
        {id=12,x=1450,y=0,race='HUMAN',general='HUMANOID'},
        {id=13,x=2200,y=0,race='HUMAN',general='HUMANOID'},
    }
    local tCore=calls.new()
    assert(#tCore:call(chain[1],chain,3,100,function() return 0.5 end).alerted==0)
    local tInsane=calls.new()
    local evInsane=tInsane:call(chain[1],chain,5,100,function() return 0.5 end)
    assert(#evInsane.alerted==2 and evInsane.alerted[1]==11 and evInsane.alerted[2]==12)
end
groups=groups+1

-- 3. Pack isolation & silent immunity: wolves howl only to wolves (never bandits, and never get verbal
-- replies), and warband calls never recruit mindless undead/constructs.
do
    local tracker=calls.new()
    local mixed={
        {id=1,x=100,y=100,race='WOLF',general='ANIMAL'},
        {id=2,x=200,y=100,race='WOLF',general='ANIMAL'},
        {id=3,x=220,y=100,race='WOLF',general='ANIMAL'},
        {id=4,x=240,y=100,race='WOLF',general='ANIMAL'},
        {id=5,x=250,y=100,race='HUMAN',general='HUMANOID'},
        {id=6,x=260,y=100,race='SKELETON',general='UNDEAD'},
    }
    local wolfCall=tracker:call(mixed[1],mixed,4,100,function() return 0.1 end)
    assert(wolfCall.profile=='pack' and #wolfCall.alerted==3)
    assert(#wolfCall.shouts==1 and wolfCall.shouts[1].key:find('^wlf_')~=nil) -- howl emote, no verbal reply!

    -- Human warband caller never recruits wolves ('pack') or skeletons ('silent'), only warband allies.
    local humanCall=tracker:call(mixed[5],mixed,4,150,function() return 0.1 end)
    assert(humanCall.profile=='warband' and #humanCall.alerted==0 and #humanCall.shouts==0)

    -- Skeleton never calls.
    assert(#tracker:call(mixed[6],mixed,5,200,function() return 0.1 end).alerted==0)
end
groups=groups+1

-- 4. Anti-spam cooldowns, lone-enemy silence, non-repeating shout rotation, reply threshold (>= 3),
-- and complete unique string table.
do
    local tracker=calls.new()
    local squad={
        {id=1,x=0,y=0,race='HOBGOBLIN',general='HUMANOID'},
        {id=2,x=120,y=0,race='HOBGOBLIN',general='HUMANOID'},
        {id=3,x=180,y=0,race='HOBGOBLIN',general='HUMANOID'},
        {id=4,x=240,y=0,race='HOBGOBLIN',general='HUMANOID'},
    }
    -- Lone caller: no allies in range -> 0 alerted, 0 shouts!
    assert(#tracker:call(squad[1],{squad[1]},4,50,function() return 0.0 end).shouts==0)
    tracker:invalidate()

    -- 3 allies alerted -> 1 caller shout + 1 reply from nearest recipient (id=2).
    local first=tracker:call(squad[1],squad,4,100,function() return 0.0 end)
    assert(#first.alerted==3 and #first.shouts==2 and first.shouts[1].id==1 and first.shouts[2].reply==true and first.shouts[2].id==2)

    -- Caller 1 on cooldown at tick 110 -> 0 alerted, 0 shouts.
    assert(#tracker:call(squad[1],squad,4,110,function() return 0.0 end).alerted==0)

    -- Separate squad at tick 120 (within minGlobalShoutGapSeconds): tactical alert works, text shout suppressed!
    local otherSquad={
        {id=21,x=3000,y=0,race='HOBGOBLIN',general='HUMANOID'},
        {id=22,x=3100,y=0,race='HOBGOBLIN',general='HUMANOID'},
    }
    local muted=tracker:call(otherSquad[1],otherSquad,4,120,function() return 0.0 end)
    assert(#muted.alerted==1 and #muted.shouts==0)

    -- After global gap (tick 400), a third squad shouts a DIFFERENT hobgoblin line than first.shouts[1].key even with rng=0.0!
    local thirdSquad={
        {id=31,x=6000,y=0,race='HOBGOBLIN',general='HUMANOID'},
        {id=32,x=6100,y=0,race='HOBGOBLIN',general='HUMANOID'},
    }
    local second=tracker:call(thirdSquad[1],thirdSquad,4,400,function() return 0.0 end)
    assert(#second.shouts==1 and second.shouts[1].key~=first.shouts[1].key)

    local all=calls.allLines()
    local seenKey,seenText={},{}
    for _,entry in ipairs(all) do
        assert(type(entry.key)=='string' and entry.key~='' and not seenKey[entry.key],entry.key)
        assert(type(entry.text)=='string' and entry.text~='' and not seenText[entry.text],entry.text)
        seenKey[entry.key],seenText[entry.text]=true,true
    end
    assert(#all==35)
end
groups=groups+1

return groups
