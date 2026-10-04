-- One stable, seeded draw among near-best scored proposals. No action submission.
local copy=require('kernel.manifest').copy
local snapshot=require('combat-intent.snapshot')
local profile=require('combat-intent.profile')
local M={}

function M.select(scoredRows,profileInput,rng)
    local p=profile.new(profileInput)
    local rows=copy(scoredRows)
    local seen,best={},nil
    snapshot.array(rows,function(row)
        snapshot.record(row,{'id','score','terms'})
        snapshot.assertKey(row.id)
        assert(not seen[row.id],'duplicate scored id');seen[row.id]=true
        assert(type(row.score)=='number' and row.score==row.score and
            row.score>-math.huge and row.score<math.huge,'finite score required')
        snapshot.array(row.terms,function(term)
            snapshot.record(term,{'reason','value','weight','contribution'})
        end)
        if best==nil or row.score>best then best=row.score end
    end)
    if #rows==0 then return nil,'no-candidates' end
    assert(type(rng)=='table' and type(rng.state)=='function' and type(rng.nextInt)=='function',
        'seeded rng required')
    table.sort(rows,function(a,b) return a.id<b.id end)
    local threshold=best-p.nearBestBand
    local band,ids,total={},{},0
    for _,row in ipairs(rows) do
        if row.score>=threshold then
            band[#band+1]=row;ids[#ids+1]=row.id
            total=total+(row.score-threshold+1)
        end
    end
    local seedBefore=rng:state()
    local selected=band[1]
    if #band>1 then
        local draw=rng:nextInt(1,1000000)
        local point=(draw/1000000)*total
        local cumulative=0
        for _,row in ipairs(band) do
            cumulative=cumulative+(row.score-threshold+1)
            if point<=cumulative then selected=row;break end
        end
    end
    return {id=selected.id,score=selected.score,seedBefore=seedBefore,
        seedAfter=rng:state(),bandCandidates=ids}
end

return M
