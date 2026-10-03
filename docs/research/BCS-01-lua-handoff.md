# BCS/Lua handoff and ordinary dialogue — integrated research batch

Status: Partial research evidence; Task11 and G1 remain open
Date: 2026-10-04
Scope: BCS-01, EEEX-03, DLG-01 and FLOW-01; authored synthetic actors only
Evidence: E1 + E2 + E3 + bounded E4, not E5 or production ownership

## Question and result

Can an ordinary creature script consult Lua, take one accepted branch, and retain its
legacy branch when the module declines or is unavailable? Can the same disposable
session exercise ordinary dialogue, rather than one launch per action?

**Yes for the nine tested bridge branches.** The authored bridge and real WeiDU component
now exist under `experiments/bridge`. The main integrated session also observed six completed
dialogue paths. A focused follow-up proved cancellation of a pending initiation and measured
loss of the queued initiation across an area exit/return. Its expectation of automatic dialogue
continuation failed; the negative result is retained, not relabeled a passing continuation.
The same follow-up loaded durable records with the entire BGSE runtime absent (see EEEX-06).
This is not acceptance of every dialogue interruption, production lease, or the mage policy.

## Environment and identity

Dedicated SCS-reference lab, separate disconnected profile; only own saves973/978 loaded.
BG2:EE file/product version2.7.3.0, EEex1.2.0, WeiDU24900, Python3.11.9, Lupa2.8
(Lua5.1 and LuaJIT2.1), pytest8.4.2. No original-game or personal-save writes, new save,
new full installation, visible desktop control, or OS input. Exact private path receipts
remain outside Git. The lab Steam DLL stayed disabled; each actual launch returned a fresh
pong with cloud saving false. One existing hidden-job launcher was reused throughout.

SHA-256 identities (effective local bytes, not an upstream-version equivalence claim):

| Input | SHA-256 |
|---|---|
| Engine | `B51093A49140B2B8A7C046B4652BB8E535BE24EBBC12B1D735E0B94217A14D57` |
| Loader | `DF0D3604CB91C127643126B7960429194F3333BCE8BAC0E59AECB6A178AC84B9` |
| WeiDU | `AD70F5897A6D0BA4B0D226F845A9B14CF345F56CC9697CA8D05CAC9FE4932C1A` |
| EEex_Trigger.lua | `BA939EC12E58B7AFC3346D42760AAA85B063624BC879DED0A47F1F9E544F8DCE` |
| EEex_Action.lua | `18EA2ED7974984D7DA66AC315CA035574CC4FAA2802F55C4F431EFCA2862787B` |
| EEex_Utility.lua | `F6BEA5AA38A4C1DA9888DDA2EE87BB26230A08CCFDD0794978825AA71A70DECB` |
| Corrected bridge BCS | `4FDD4A4E5C8F2650F54599D4B02F0BED3CE28F1357109D0DA677703F93C13865` |
| Authored dialogue DLG | `03809EF16F5CC9594F90B0762CC917A6B8EF06AD7078F2F82D0C7292147D4A34` |

The pinned effective trigger/action helpers set their respective executing-object variable,
then evaluate the supplied Lua. The bridge passes its scalar ID for in-session equality;
no userdata or ID is retained in saved state or exported receipts. Generated CRE/BCS/DLG,
copied TLK and decompiles stay private. The caster derives from the existing stripped
research donor; its full byte/slot identities are in `fixture-build-v3/build-identities.json`.

## Method and reproducible checks

1. Assign distinct synthetic-only resource stems in `experiments/bridge/README.md`.
2. Run `python -m pytest tests/unit tests/integration/test_bridge_installer.py -q -p no:faulthandler`.
   The installer uses a minimal authored KEY/BIFF/TLK/IDS game, not the lab. Supply the
   recorded WeiDU via `BGSE_WEIDU` when the documented local default is unavailable.
3. Privately build the four published bridge files and stripped CRE, using a copied lab
   TLK for the three authored strings. Decompile all BCS/DLG from the fake-game working
   directory with WeiDU `--use-lang en_us --out <private-output> <compiled-files>`.
4. Reserve the existing lab, stage the exact18-entry ledger with originals backed up,
   prove non-input-desktop isolation, start the held job, **then** send the first pong.
5. Load own973 through the existing queued-menu helper; move to the quiet BG2602 fixture;
   create only the explicitly named research caster. Run all nine bridge cases in one
   session, 60 simulation ticks each. Verify marker outcomes and independent Lua action notes.
6. In that session, initiate the authored dialogue through `StartDialogNoSet(Player1)`;
   wait for actual text and two choices, queue the existing internal confirm button, and
   verify the speaker's reply local after the conversation closes. Extend that same session
   with missing-target, recipient-Wait, disabled-receive-flag and restoration cases.
7. Close only the owned job, verify its processes absent, reconcile every staged target,
   restore original TLK/ARE/UI/config bytes, remove owned IPC, and token-release the reservation.

The follow-up `absence-and-area-v1` uses the same recipe with16 staged targets: omit the BGSE
bootstrap and observer entirely. First load own978 and verify EEex's raw fallback packet;
then load own973, create the same research caster, and queue Wait/dialogue/tail. After observing
Wait63 and two queued actions, request ordinary ActionOverride movement. Require action23,
actual displacement, later idle/empty queue and unchanged reply/tail, not exact point arrival.
Queue a second Wait/dialogue, observe it, move the PC to BG2600 and back to BG2602, re-resolve
the marked own actor, and observe without resubmitting the dialogue. Stop at the25-second
batch deadline. This is one reviewed correction and added area measurement, not a retry loop.

Private recipes/receipts: `.work/task11/bridge-runtime-v1`, `v2`, `v3`; build outputs
`fixture-build-v1` through `v3`. Do not rerun or overwrite these completed directories.
The main integrated trace is604 rows/25715bytes plus header. Dialogue/adverse receipts carry additional
scalar observations; the final nested console receipt truncates deep event tables, so use
the earlier full script-result receipt and TSV, not that nested receipt alone.
The follow-up closed382-row/17862-byte trace has SHA-256
`8C7F7A7D9EAE6AEEF487CC1FEBDA1BB104015B79F757070E70CD6529BDD83833`.
All16 staged targets were reconciled and owned IPC removed after the owned processes stopped;
the matching reservation was released. No save was made. Cleanup verifies owned-process
absence; no graceful game exit-code claim is made.

## Observations

| Case | Observed result |
|---|---|
| Bridge module absent | Legacy marker2 |
| Higher slot blocks | Marker0; armed module never claimed; no claim about a particular NoAction execution |
| Higher slot continues | Higher marker1, bridge marker1, accepted claim and subsequent Lua action note |
| Policy declines / deliberately errors | Legacy marker2; corresponding false/error reason |
| Capability missing / bridge disabled | Legacy marker2; no accepted claim |
| Public Lua root absent | Legacy marker2; this is not full callback/runtime unloading |
| Fresh explicit rearm | Marker1 and separate Lua action note |
| Ordinary accept / player decline | Correct authored entry, two choices, reply locals1/2 after close |
| Missing object selector | Ordinary authored conversation still opened and replied2; not a failed initiation |
| Recipient executing Wait | Current action63 observed with one queued tail before request; conversation completed while that Wait/tail remained |
| DialogInterrupt(FALSE) on recipient | Tail marker13 observed, yet conversation opened; after explicit TRUE/tail14, ordinary positive control also completed |
| Pending initiation interrupted | Wait63/queue2 at tick32642; action23 and displacement observed; tick32762 idle/queue0, reply0/tail0 |
| Area exit/return with pending initiation | Wait63/queue1 at tick32762; PC observed BG2600 at32771, returned BG2602 at32825; own actor idle/queue0/reply0 through33014; no automatic continuation |

The missing-selector result agrees with the documented Player1 fallback of
[StartDialogNoSet](https://gibberlings3.github.io/iesdp/scripting/actions/bgeeactions.htm#198).
Conversely, the recipient-flag observation limits any inference from the broad
[DialogInterrupt description](https://gibberlings3.github.io/iesdp/scripting/actions/bgeeactions.htm#179).
These are evidence to require explicit target/eligibility validation before dispatch, not
permission to retarget an adapter silently. All dialogue cases ran with this bridge disabled;
ordinary DLG ownership did not depend on its policy module.

## Failures, fixes and counterevidence

- Initial host RED: missing module/installer. Later execution of actual BAF payloads caught
  `_G[[B-]]` being a Lua string-argument call, not indexing. Explicit `_G[ [[B-]] ]` passes on
  both backends; the installer test verifies byte-exact payload retention in compiled BCS.
- The first synthetic IDS fixture had three wrong constants. Comparing effective IDS fixed
  Global=0x400F, True=0x4023, Continue=36. Further harness corrections recognized textual
  compiled BCS, normalized path keys, and WeiDU's retention of allocated dialogue strings.
  Install/reinstall/uninstall now prove exact resource restoration and original string content;
  uninstall does not shrink the language TLK. Actual lab cleanup restores the original TLK.
- First engine session: accepted Lua claim and action note **also** ended with legacy marker2.
  Removing only the accepted block's `Continue()` fixed this in two later nine-case runs.
  It had allowed further condition evaluation before the queued marker update excluded the
  fallback. The higher-slot Continue remains. A focused compiled-code regression failed first,
  then the combined host/synthetic command passed13 checks (0.49s at correction).
- A premature pong caused one helper to refuse before launching any game. Its command was
  preserved/removed after own-process checks; launch-before-pong ordering fixed it. An early
  QA status assertion used `completed` rather than the helper's `complete`; it failed before
  movement and was corrected. Neither failure is represented as successful game execution.
- Second session's dialogue harness checked too early and did not service IPC in the dialog.
  Corrected rendering-hook polling captured empty text/zero choices first, then the actual
  authored text/two choices in the same simulation tick. Normal queued confirmation passed.
- Final pending-interruption case: observed Wait63 with two queued actions; ordinary external
  ActionOverride movement left the actor idle with an empty queue, moved from304,192 to232,270,
  and left reply/tail markers0. The harness demanded exact232,264, failed, and its original
  dialogue monitor later timed out. That run was stopped without relaxing an assertion or retrying.
  These measurements support bounded cancellation-before-entry; **the whole transition case is
  not a pass**, and its subsequent area-change leg never started.
- The reviewed follow-up corrected the movement criterion before running and proved the bounded
  cancellation case. The added area case then disproved the harness's continuation expectation:
  the queued initiation was not observed after return. The deadline failure is preserved. Do not
  infer that an adapter can resume a stale pre-transition request, or turn a new request into
  evidence that the old one survived. No already-open conversation interruption was tested.
  No native crash occurred.

## Remaining work and decision boundary

Task11 remains in progress: its bridge, installer and representative dialogue evidence are
assembled, but transition acceptance remains open, alongside Task10 and G1. Area transition is measured
negative evidence, not a passing automatic-continuation capability. Interruption here is
cancellation before entry, not closing an already-open conversation. Full module-absence
load retention is now observed (EEEX-06); absent-session resave/re-enable remains outside that
specific result. True QuickLoad is still unproved. Named loading of a quicksave is not true
QuickLoad; no allowed source-backed callable was found, so do not guess one or waive it.

G1 stays open. No real actor enrollment, production AI, support-matrix expansion, SCS-derived
redistribution, new gameplay choice or automatic downstream approval follows from this batch.
The next product target remains the representative multi-behavior mage, using coherent parallel
implementation and combined scenario runs rather than one launch/review/report per spell.
