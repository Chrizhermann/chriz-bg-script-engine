# REC-01: playtest recorder

Component `10` (`bgse-recorder`) is an optional EEex observer. It writes one JSON object per
line to `bgse-playtest/<date-time>.jsonl`, relative to the game directory. Set
`[BGSE] Recorder=0` in `Baldur.lua` before startup to turn it off; it is on by default.
The component creates `bgse-playtest` when it installs. If that folder is later missing or the
file cannot open, the recorder disables itself with one log line; it never starts a shell.

It records the session difficulty, party and starting area; each detected reload; area and pause
changes; world-screen key names; action-bar callbacks; party action starts; and changed party
queues. Action resource strings include numeric `SPELL.IDS` casts (`SPPR`, `SPWI`, `SPIN`, or
`SPCL`) when their action string is empty. A fight begins when a living EA 200+ creature is in a
party member's normal 448-pixel sight search. Searches run at most once per 15 game ticks and
never while paused. A fight closes after 90 game ticks without a foe, or when the party area
changes. Start rows include each member's position, equipment, quick slots, quiver, pack,
memorized spells and stats, plus seen foes. End rows include current hit points, deaths, dead foes
and positive spell/item-use differences. When the main engine is present, `eng` rows copy its
director (`tag: "dir"`) and choice (`tag: "ch"`) trace rows. It never queues actions, applies
effects, writes game variables, or writes save data.

Every row has `k` and `t`; `t` is the game's tick counter. Rows are deliberately interpreted in
file order: ticks can move backwards after a load. The recorder buffers its single open output
file, flushes about once a second and at fight end, and starts another file after 500,000 rows.
Run `python -I tools/read_playtest.py bgse-playtest/<file>.jsonl` for a per-fight summary of
length, action starts by member, spending, pause transitions and reloads before the fight.

Not verified in a game yet

- Queue contents: while paused, give one party member a visible move and a spell/item order, then
  paste this in the lab remote console. A result listing the same action IDs, target instance and
  resource strings as the UI queue proves the fields the recorder reads. For an empty string on a
  cast, the displayed `specific` value in 1000--4999 must map to the same `SPPR`/`SPWI`/`SPIN`/
  `SPCL` resref that the record writes.

  ```lua
  local p=EEex_Sprite_GetInPortrait(0);local r={}
  EEex_Utility_IterateCPtrList(p.m_queuedActions,function(a)
    r[#r+1]={id=a.m_actionID,target=a.m_acteeID and a.m_acteeID.m_Instance,
      res=a.m_string1 and a.m_string1.m_pchData and a.m_string1.m_pchData:get(),
      specific=a.m_specificID,dest={x=a.m_dest.x,y=a.m_dest.y}}
  end)
  return r
  ```

- Paused ticking: open a game, record `BGSE_RECORDER:inspect().ticks`, pause for a few seconds,
  then read it again. A larger second value proves the hidden menu's enabled callback ticks during
  pause (and therefore can see changed paused queues).

- Load count: note `BGSE_RECORDER:inspect().loads`, load a named save once, wait for the world
  screen, and read it again. Exactly one additional count plus one `load` JSON row proves the
  lifecycle interpretation used here.

Automated tests cover JSON encoding, queue equality, fight spending differences, the fake-EEex
observer flow, standalone installation and the absence of an import from combat code into this
component. They do not prove those three runtime observations, actual listener timing, or the
engine's queue representation.
