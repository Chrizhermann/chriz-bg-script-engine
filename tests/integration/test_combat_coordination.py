"""One representative two-mage plan, entirely scalar and outside the game."""
import importlib
from pathlib import Path
import pytest

ROOT = Path(__file__).resolve().parents[2]

@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_two_mage_coordination(backend):
    lua=importlib.import_module('lupa.'+backend).LuaRuntime()
    lua.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert lua.execute('''
        local intention=require('combat-intent.intention')
        local reservation=require('combat-intent.reservation')
        local values=require('kernel.manifest')
        local a={adapterId='B-/combat/mages',key='mage/one',resource='B-XPMAG0.CRE'}
        local b={adapterId='B-/combat/mages',key='mage/two',resource='B-XPMAG1.CRE'}
        local function context(tick)
            return {sceneKey='encounter/one',groupKey='squad/one',tick=tick,combatActive=true,
                members={a,b},targets={'enemy/one'},spaces={'safe/one'}}
        end
        local function frame(who,tick)
            return {sceneKey='encounter/one',tick=tick,identity=who,enabled=true,combatActive=true,
                facts={target='enemy/one',targetAlive=true},legalSteps={reposition=true,slow=true}}
        end
        local function plan(who)
            local p=intention.new({identity=who,sceneKey='encounter/one',maxSteps=2,maxLifetimeTicks=20})
            assert(p:begin({purpose='move then try control',steps={'reposition','slow'},expiresAt=20,
                assumptions={target='enemy/one',targetAlive=true}},frame(who,0)))
            return p
        end
        local board=reservation.new({sceneKey='encounter/one',groupKey='squad/one',maxEntries=3,maxLifetimeTicks=20})
        local pa,pb=plan(a),plan(b)
        local effect={kind='effect',targetKey='enemy/one',effectKey='slow',expiresAt=15}
        local claim=assert(board:reserve(a,effect,context(0)))
        local no,why=board:reserve(b,effect,context(0))
        assert(not no and why=='reserved-by-peer')
        local space=assert(board:reserve(a,{kind='space',spaceKey='safe/one',expiresAt=5},context(0)))
        assert(not board:reserve(b,{kind='space',spaceKey='safe/one',expiresAt=5},context(0)))
        -- Capture the actual advisory input alongside the plan: no hidden score modifier.
        local trace={coordination=board:view(a,context(0)),next=pa:next(frame(a,0))}
        assert(trace.coordination.dispatchAuthorized==false and trace.next.dispatchAuthorized==false)
        assert(#trace.coordination.claims==2 and trace.next.step=='reposition')
        assert(pa:observe(trace.next.token,{kind='accepted'},frame(a,1)))
        assert(pa:observe(trace.next.token,{kind='started'},frame(a,1)))
        -- A successful move does not itself dispatch Slow. Fresh plan legality is still required.
        assert(pa:observe(trace.next.token,{kind='completed',proof='independent-postcondition'},frame(a,2)))
        assert(board:release(a,space.token))
        local cast=pa:next(frame(a,2));assert(cast.step=='slow')
        assert(pa:observe(cast.token,{kind='accepted'},frame(a,3)))
        assert(pa:observe(cast.token,{kind='started'},frame(a,3)))
        assert(pa:observe(cast.token,{kind='interrupted',reason='target moved'},frame(a,4)))
        assert(pa:inspect().status=='aborted' and board:release(a,claim.token))
        assert(not pa:next(frame(a,4))) -- no automatic retry by the first mage
        assert(board:reserve(b,effect,context(4)))
        assert(pb:next(frame(b,4)).step=='reposition')
        -- Semantic target loss cancels the intention and removes the group's claim.
        local gone=frame(b,5);gone.facts.targetAlive=false
        assert(not pb:next(gone))
        local current=context(5);current.targets={}
        assert(#board:view(a,current).claims==0)
        -- Scene/load invalidation discards both mechanisms, not persisted native handles.
        pa:invalidate('load');pb:invalidate('load');board:invalidate('load')
        assert(not board:view(a,context(6)) and not pa:next(frame(a,6)))
        assert(values.copy(trace).next.step=='reposition')
        return true
    ''')
