# SCS mage pilot: target and protection boundary

**Outcome:** Conditional; source-only call-site map, not resolved target semantics.

**Question:** What must be expanded before a target/protection rule can become a policy oracle?

**Environment:** env:host; game-state access none.

**Versions and fingerprints:** SCS v35.21 pin/digests in
[scs-source-pilot.evidence.json](scs-source-pilot.evidence.json).

**Method:** Inspect one early-dispel call site and the ordinary Spell action definition using
[the pinned-source recipe](SCS-01-generation-pipeline.md). No full library expansion performed.

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
[manifest](scs-source-pilot.evidence.json).
[Dispel call site](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/ssl/combatblocks/first_dispel.ssl#L7-L31).

**Applicable evidence:** evidence:E1 for call-site/definition observations only.

**Residual uncertainty:** Follow target/trigger library bodies, SR/EE variants, generated spell
resources and all substitutions before completing the oracle. No complete protection table exists.

**Next decision:** Lead owns macro interpretation; a bounded worker may extract pinned definitions
and cross-references. Unresolved forms remain `opaque`, never permissively generalized.
