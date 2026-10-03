# Current-stack observer compatibility checkpoint

Date: 2026-10-04. Evidence: E1/E2/E3/E4, each bounded below. No E5 or broad support claim.

## Question and environment

Does the explicit observer preserve unrelated bytes/legacy behavior, including a genuinely
changed character and an independent public-state controller? Same pinned lab as KERNEL-01:
BG2:EE2.7.3.0, EEex1.2/LuaJIT, EET14, SCS35.21, SR4.21-chriz.5, Spell Menu5.2;
WeiDU24900 for host fixtures. No older, missing or mixed runtime is admitted.

## Host implementation and evidence

The existing bridge installer previously overwrote each of its four fixed output names.
Four newly written collision tests failed for that reason. An action-phase preflight now refuses
before COMPILE/COPY; it runs after WeiDU unwinds an existing installation so legitimate reinstall
still works. Eight focused integration checks pass. Arbitrary unrelated BCS/DLG/CRE byte sentinels
are unchanged across install/reinstall/uninstall, and the publication allowlist remains exactly
four authored bridge outputs. WeiDU's retained language-TLK strrefs are recorded, not called
byte-exact TLK restoration. Snapshot comparison excludes WeiDU's own log/backup bookkeeping.

This is real WeiDU E3, but not a full observer installer, KEY/BIF collision test, opaque-format
parser, bootstrap publication, exclusive-variable registry or all-upgrade matrix. Duplicate
adapter IDs and exact closure drift remain separately exercised E2 kernel behavior.

## Integrated engine method

Reused the Task16 bundle and four ordinary caster scripts in one hidden session. Actor1's
effective CRE actually changed: override `B-XKLEG0` → `B-XKALT0`. The new script first writes its
own local marker, then has the exact same ordinary cast/move blocks. Expected declaration is the
true original CRE digest/slot; observation contains the actual changed digest/slot. No invented
expected digest in this run. Byte differences were limited to the intended override field.

A fifth authored, **unenrolled** controller used `B-XKCTL0`: while armed, ordinary BCS increments
the private GLOBAL `B-XQST00` then `Wait(1)`. This is a quest-style public-state sentinel, not a
production quest migration. The kernel never writes that global. Counter progress checks span
the ordinary/error, missing capability, individual disable and stale-state windows.

All six sprites (own protagonist, four casters, one controller) settled before the probe loaded.
The first planned batch passed without runtime retry. Review beforehand found a test gap where
an invalid callback assertion could be swallowed by its own adapter circuit; the harness now
sets and checks an independent forbidden-callback flag, verifies both eligible observers ran,
and requires the changed actor's clean circuit plus explicit hash-mismatch trace.

## Observations

- All four ordinary self-casts: one matching action31/SPWI214 start each, ready copies2→1,
  later source-SPWI214 opcode44, followed by distinct displacement/goal, idle/empty/done1.
- Changed actor1 executed its alternate-script local marker and legacy sequence, with zero
  callbacks and no adapter error. Unregistered actor3 also completed with zero callbacks.
- Eligible actors0/2 received102/139 callbacks. Actor2's one injected callback exception was
  contained and recovered; actor0 continued. This is not a native-crash recovery claim.
- The unknown controller counter advanced0→16 across the batch, including each later failure
  window. It was never enrolled. No assertion equates Lua command acceptance with that outcome.
- Drift latched all adapters stale; restoring the old epoch did not reactivate them.
- Loading own baseline973 caused one destroyed event, enrollment3→0 and counter16→0. No new save.

The closed2009-row scalar trace has no failed event. Exact source and private receipts are under
`.work/task17/{bridge-preflight-v1,fixture-build-v1,compat-runtime-v1,host-final-v1}`.

| Artifact | SHA256 |
| --- | --- |
| Runtime session source | `eb90285253defafe419a6a8dd5fa517eb2a20f9fc47efceb3feb1c978e520e70` |
| Closed behavior trace | `2614af5e98bd761ad48e3fcf510a876eb8ed7e7b122b27a2afe6c5cf632a0d76` |
| Final result receipt | `c8e240a4055c3325bcdb83d5b2cce6163fbd3985297d3ac546c41a0975bce1e0` |

## Limits, counterevidence and disposition

The environment's completeness flags still describe an authored observer fixture, **not** a
discovered whole-game dependency/public-state closure. Actual bytes/slots were compared, but
no real SCS adapter was activated. The sentinel global is not a claimed WorldFlow ABI.
The controller progresses under the later failure windows; the casters' already completed
casts are not evidence of new casts in those windows. No uninstall/partial EEex behavior inferred.

Latest user direction makes broad runtime/version compatibility secondary to current-stack
development. Missing/mixed/removed-runtime and cold all-bridge package checks remain in Task40
before their support/distribution claims; they are unavailable, not passed. Current exact output
collisions, unknown ownership and implemented boundary failures remain immediate requirements.
This completes Task17's **development-only** checkpoint; G2/G3 must explicitly retain its scope.

Lead rechecked outputs; independent review verifies source and full trace. Own hidden job stopped;
all16 staging targets reconciled (three originals restored, thirteen additions removed), own IPC
preserved/removed and matching token released. No active-game/personal-save access, new copy or
save. An attempted hash while the trace was open met a normal sharing refusal; the final hash
above was taken after close. Nothing was retried or unlocked to bypass it.

Final combined host run:172passed across16files, exit0; Python3.11.9, pytest8.4.2, Lupa2.8,
Lua5.1/LuaJIT2.1.1774896198. Current compatibility glue compiled on both without execution.
Native listener handlers legitimately receive userdata; only the kernel policy/snapshot path
is scalar-only. The final receipt's cached `controller=16` is pre-load; reset-to0 is proved by
the successful explicit post-load assertion, not that cached field.
