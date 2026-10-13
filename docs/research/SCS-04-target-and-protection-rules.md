# SCS mage pilot: target and protection boundary

**Outcome:** Conditional; original source-only call-site/shared-rule checkpoint, extended below
by one E1 installed-output comparison. Not runtime semantics.

**Question:** What must be expanded before a target/protection rule can become a policy oracle?

**Environment:** Original source checkpoint: env:host, game-state access none. The linked
installed continuation inspects only the approved copied lab offline; no engine/save access.

**Versions and fingerprints:** SCS v35.21 pin/digests in
[scs-source-pilot.evidence.json](../../archive/2026-10-process/docs/research/scs-source-pilot.evidence.json).

**Method:** Inspect one early-dispel call site and the ordinary Spell action definition using
[the pinned-source recipe](SCS-01-generation-pipeline.md). The
[shared-rule continuation](SCS-shared-rule-expansion.md) additionally traces six selected macro
names across seven libraries and the Perl reader; no full library expansion was executed.

**Observations:** `first-dispel`, 7-31, combines ordered player targeting, several named protection
and dispel-safety macros, level/chapter gates, a time-stop condition, timers, combined alternatives
and continuation handling. Its action arguments carry weights that must be interpreted by SSL,
not mistaken for already emitted BCS response probabilities.

The ordinary `Spell` definition (`caster-definitions`, 18-33) adds availability, casting-timer,
targetability, sanctuary, caster spell-failure and do-not-target checks before a normal Spell
action. This is one action family, not a universal legality predicate for every caster action.

**Counterevidence:** Named macro calls are not their bodies. Alternate spell/action definitions
exist, and install libraries differ. A readable name such as a protection check is not sufficient
evidence of exact immunity semantics, target visibility or friendly-fire safety.

**Artifacts:** `artifact:scs3521-first-dispel`, `caster-definitions` in the
[manifest](../../archive/2026-10-process/docs/research/scs-source-pilot.evidence.json).
[Dispel call site](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/ssl/combatblocks/first_dispel.ssl#L7-L31).

**Applicable evidence:** evidence:E1 for source and the linked installed-file observations only.

**Installed continuation:** The [higher-level mage comparison](2026-09-28-scs-high-mage-dispel.md)
now checks this branch in MAGE18B's generated script. Three reversed selector blocks precede a
sequencer and an ordinary area-spell candidate; the non-casting weighted response also writes
the firstdispel timer. Library predicates and the installed spell alias are compared explicitly.
This extends the source-only account with E1 output, not observed target selection or casting.
The 2026-10-04 continuation in that report also maps ordinary Breach to six repeated full target
blocks, preserving the separate castspell/three combat timers and its Continue-only weighted skip.
PRIORITY_BREACH is an emitted marker check with a separate DS source input, not a protection list
that can safely be reconstructed from the call-site comment. No Breach cast or removal is proved.

**Residual uncertainty:** Six selected library bodies and ordinary-versus-replacement merge rules
are now source-traced, and selected effective substitutions are characterized in one actor;
other libraries, generated spell resources and historical generation inputs remain open before
completing the oracle. No complete protection table or engine predicate proof
exists. A comment-only ordinary SR entry does not erase an earlier predicate.

**Next decision:** Lead reviews actual library/compiler inputs and effective output against the
source trace. Unresolved forms remain `opaque`, never permissively generalized.

## True Sight comparison — 2026-10-04

**Question:** Can a self-cast detection rule be mapped as a family without confusing its observed
enemy with the spell's recipient? Same MAGE18B/copied stack and hashed BAF as the higher-level
report; no new decompile, engine run or mutation.

Pinned [truesight.ssl7–15](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/ssl/combatblocks/truesight.ssl#L7-L15)
matches effective BAF8110–8246: six complete candidate blocks, nearest through sixth-nearest
enemy. Each checks See(candidate), castspell not unexpired, HaveSpell(WIZARD_TRUE_SIGHT) and caster
spell-failure<60; requires enemy caster and non-ENEMY candidate; and requires a disjunction of
candidate mirror-image state, ILLUSIONARY gender, improved invisibility or invisibility.

The repeated coverage guard checks the TRUE_SIGHT **stat** on four ENEMY-allegiance object
selectors (fourth-nearest, third, second, `[ENEMY]`) plus Myself. Preserve those expressions;
they are not a scan of all allies, a whole-party coverage guarantee or a shared reservation.
The [library bodies470–481](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/library.slb#L470-L481)
match these distinct coverage and target-illusion scopes. Absent-object behavior and See against
the invisibility states are not proved by the BAF; do not infer omniscient detection.

Each single weight100 response sets castspell=ONE_ROUND then requests normal
Spell(**Myself**,WIZARD_TRUE_SIGHT). The candidate determines why the action is useful, not its
recipient. There is no second weighted Continue response or explicit spell-removal action in
this region. This matches [SpellMyself177–188](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/caster_shared/caster_definitions.ssl#L177-L188),
not the ordinary enemy-targeted Spell action definition.

Indiscriminate/IsLich and the definition's SSLBoolean are generation filters, not emitted runtime
conditions. Source SIDivination is absent in this output, consistent with SR's explicit
[blank replacement11–12](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/library_sr.slb#L11-L12).
This is a real distinction from SIAbjuration's append-only declaration, not permission to discard
immunity tests globally.

**Counterevidence / scope:** The source also has SR Detect Invisibility and lich Oracle/True Sight
forms. Those forms were not identified in this actor's output. An earlier Oracle cast and other
True Sight occurrences do not have this branch structure and are not evidence of those alternate
forms surviving. Do not infer why an absent alternative was pruned. Installed numeric namespaces
also differ: spell WIZARD_TRUE_SIGHT=2609, stat TRUE_SIGHT=118, state DETECT_INVISIBILITY=143;
spell WIZARD_DETECT_INVISIBILITY=2203 and WIZARD_ORACLE=2515. A shared display label is not an
interchangeable ID.

**Disposition and evidence:** `preserve` candidate-versus-recipient, coverage scopes, normal
action/timer order and installed library substitutions; `needs-engine-proof` for actual selection,
delivery, spell expenditure and removal of illusions. E1 only, not a complete detection/perception
policy, ownership claim or observed cast. No tactical change is proposed.

**Artifacts and reproduction:** Existing source/BAF identities plus the direct-include index in
SCS-02. truesight.ssl pinned raw SHA-256
`A1699E60CA053818C3080B5D8C7742F5C47FF7C9C10369548B06025057AA94B7`, copied-lab raw
`17F56CFD2FAAA82F25B05FECDD4CAC84901E0B2062C81D36BA78B694E3F8E1BE`; normalized content matches.
Inspect the six complete BAF blocks, not only spell-name matches. SCS by DavidW, SR by
Demivrgvs/G3; authored metadata only, no source or behavior fixture admitted to Git.

**Review:** Independent source/output extraction and lead full-block inspection agree. A final
wording review corrected abbreviated spell names to their exact WIZARD_ aliases so the paragraph
itself does not blur spell and stat namespaces. No runtime claim or new test case was added.
