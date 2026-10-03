# Combat candidate inputs — current lab

**Question / outcome:** Which installed resources implement the planned three-spell shadow
set, and can we safely derive targeting from their names? Names are insufficient. Exact
resource identities and selected fields are verified; full geometry/recipient closure is not.

**Environment:** Read-only approved SCS-reference lab, BG2:EE2.7.3, EEex1.2, SCS35.21 and
SR4.21-chriz.5. No engine or installer was started for this inspection. Its stack record is in
the [installed mage comparison](2026-09-27-scs-effective-mage-pilot.md).

## Verified inputs

Installed SPELL.IDS lines287/331/352 resolve Magic Missile2112, Glitterdust2224 and Slow2312.
The numeric ability projectile must be converted to PROJECTL.IDS using **N-1**, as documented
in the [SPL extended-header format](https://gibberlings3.github.io/iesdp/file_formats/ie_formats/spl_v1.htm).
Raw range values below are not area-coordinate pixels or an implemented distance conversion.

| Spell / resource | Ability observations | Projectile resolution |
|---|---|---|
| Magic Missile / SPWI112 | Creature target1; levels1/3/5/7/9; range30; casting1 | Raw68–72; no corresponding installed IDS entries67–71. Hardcoded behavior needs its own evidence, not an invented PRO file. |
| Glitterdust / SPWI224 | Point target4; level1; range20; casting2; child SPWI224E | Raw425 -> IDS424 `DVGLDUST`, not IDS425 `DVFARROW`. |
| Slow / SPWI312 | Point target4; levels1/10/15/20/25/30/35/40/45/50; range30; casting3; child SPWI312D | Raw159 -> IDS158 `INAREANP`, not IDS159 `SPARBLPA`. |

Glitterdust's child has ten creature-target abilities at levels1/8/13/18/23/28/33/38/43/48,
range20/projectile1, and itself references SPWI224D. Slow's child has ten matching level
thresholds, creature target, range30/projectile1. Casting features reference DW#BLHDA separately
from target payloads; do not equate one parent ability with a complete effect/dependency graph.

Both actual area PROs are768 bytes/type3/extendedFlags0/areaFlags64. DVGLDUST has raw trigger
size256, explosion size110 and explosion projectile48; INAREANP has256/256/0 respectively.
These are fields, **not** a proved circular hit model, ally-safe classification, child-projectile
interpretation or engine range/LOS result. Field documentation:
[PRO format](https://gibberlings3.github.io/iesdp/file_formats/ie_formats/pro_v1.htm).

## Reproduce / identities

Resolve the approved lab from `.work/task3/practical-lab-20260927.json`. Use the existing private
read-only `.work/task6/high-mage-20260928/inspect-trigger.ps1 -Resources
@('SPWI112','SPWI224','SPWI224E','SPWI312','SPWI312D')`; it reads the actual header offsets and
indexed40-byte ability/48-byte effect slices. Read range at each ability+0x0E. Resolve PROJECTL
with N-1, accepting decimal and hexadecimal IDS keys. For the two PROs read type@0x8,
extendedFlags@0x2C, areaFlags@0x200, trigger@0x204, explosionSize@0x206 and
explosionProjectile@0x21A. All files here are effective `override` resources.

| Artifact | SHA-256 |
|---|---|
| SPELL.IDS | `1FD84A38609DAB514BFE94A527943F103C9E860B32DE77B03DDD601F934EEFD1` |
| PROJECTL.IDS | `B4660B6656DE2EBA472DE766EA59C47BB1AF14CF1B0373B5B2305CC1B36159B3` |
| SPWI112.SPL | `C7600DEB3D733624919E585552156CF555F5CA7C79CE2306A92C077B75108EE4` |
| SPWI224.SPL | `00E814AB61B9EFBA90CBE440FD7313AEB7EE69BE1247AB8E95C913F11F810961` |
| SPWI224E.SPL | `603B6242D593320BDD6BD4CAF411DBF41EF58C7CCC6EE2A3E6EEB221EF469CEB` |
| SPWI312.SPL | `C1758005FD494A9445A0E6C6457567CE4229E5B5F9181FCA7825CC18B86EA38E` |
| SPWI312D.SPL | `B9D9DE600C5FD52FA9E958F394E520E1C4BA2CC16DB30941F418C6079CB1C2C2` |
| DVGLDUST.PRO | `FC60A681D7F36F0DED4D6192EE968964AF85C870CA8AB6E5A898C219CD276994` |
| INAREANP.PRO | `FF8B9B888A1BDF476D33DCDD63078D402D941CB0AAEA306981B10645C509E61A` |

**Counterevidence / review correction:** Initial worker extraction looked up the raw projectile
number directly and reported the neighbouring DVFARROW/SPARBLPA entries. Lead inspection of
primary documentation caught the off-by-one, repeated the actual byte/hash checks and resolved
the correct PROs. The erroneous geometry attribution is rejected, not used by the candidate
code. A generic knowledge-reference field label was corrected to prevent repeating this.

**Evidence / uncertainty / next step:** E1 pinned effective bytes; E0 current format-document
interpretation; no E4 delivery or complete closure claim. Resource origins and final component
owners are not inferred from prefixes and remain unverified for this new table. Attribution:
SCS DavidW, Spell Revisions Demivrgvs/G3; no upstream bytes or reconstructed policy distributed.
Task21's host tests use deliberately synthetic geometry/thresholds, not these installed facts as
an activation manifest. Complete the bounded native mapping/geometry evidence and ledger-approved
prebuff accounting before claiming the whole candidate task or G4. No gameplay values chosen.
