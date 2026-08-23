# P13 — Budget an End-to-End Deadline

**Track:** Distributed Real-Time Systems and Networks  
**Phase 4:** Real-time networking  
**Status:** implemented

## Guiding question

What inputs, observable effects, and failure modes matter when you budget an End-to-End Deadline?

## Compounds on P12

P04 made queue wait a separate latency component. P11 showed that backpressure can move overload
upstream without making service faster. P12 exposed when one proposal has enough coordination
evidence; its baseline third vote appears at `26 ms`. P13 treats those quantities as declared
inputs to one sequential transaction and asks a new question: is every causal stage owned exactly
once, does each stage fit its allocation, and does the complete path fit its end-to-end deadline?

The `26 ms` coordination contribution is reused as an input. P13 does not rerun or extend the P12
quorum evaluator, and it does not implement periodic scheduling, QoS, or admission control; those
belong to P14–P16.

## Computational mental model

The transaction crosses five ordered stages. For declared analytical contribution `c_i`, assigned
stage budget `b_i`, and end-to-end deadline `D`,

`R_e2e = sum(c_i)`

`S_e2e = D - R_e2e`

`M_i = b_i - c_i`

`R_e2e <= D` is the complete-path deadline test. A maintainable allocation plan additionally owns
every causal stage, keeps every `M_i >= 0`, and satisfies `sum(b_i) <= D`. When coverage is
complete, the visible accounting identity is

`D - sum(c_i) = [D - sum(b_i)] + sum(b_i - c_i)`.

The left side is end-to-end slack. The first term on the right is unassigned deadline reserve; the
second is the sum of stage margins. A negative stage margin can occur while total path slack stays
positive: spare margin elsewhere absorbs the overrun at the top level, but the local allocation
breach still needs an explicit rebudgeting decision.

The fixture uses these five declared contributions and reference allocations:

| Stage | Declared baseline contribution | Reference allocation |
| --- | ---: | ---: |
| Source task response | `8 ms` | `10 ms` |
| Queue/admission wait | `12 ms` | `16 ms` |
| Serialize + network | `10 ms` | `14 ms` |
| Coordination evidence wait | `26 ms` | `32 ms` |
| Destination task response | `9 ms` | `12 ms` |

“Declared” is important. The values are synthetic teaching inputs, not measured or certified
WCET, queue, protocol, link, clock, or response-time evidence.

## Deterministic baseline

The baseline uses queue wait `12 ms`, coordination wait `26 ms`, deadline `90 ms`, and complete
coordination-stage ownership.

- Contributions `[8 12 10 26 9] ms` sum to a complete path of `65 ms`.
- Allocations `[10 16 14 32 12] ms` sum to `84 ms`.
- Stage margins are `[2 4 4 6 3] ms`, totaling `19 ms`.
- The allocation plan leaves `90-84=6 ms` of unassigned reserve.
- End-to-end slack is `90-65=25 ms`, equal to `6+19 ms`.
- Every stage is represented once, every stage fits, the allocation sum fits, and the modeled plan
  is credible under its declared inputs.

These are deterministic arithmetic values. They are not observations from MATLAB execution,
tasks, schedulers, queues, consensus processes, packets, links, clocks, or hardware.

## Controlled experiments

1. Read `R_e2e=sum(c_i)` and the slack identity, then predict whether one stage can exceed its
   allocation while the complete path still meets `D`.
2. Inspect stage contribution beside stage allocation, one unit-labeled view at a time.
3. Change to cumulative complete-path and allocation views, then account for the `6 ms` reserve
   and `19 ms` of stage margin.
4. Sweep only queue/admission wait through `[0 6 12 24] ms`. Complete-path contribution becomes
   `[53 59 65 77] ms`; deadline slack becomes `[37 31 25 13] ms`; queue-stage margin becomes
   `[16 10 4 -8] ms`. The last path still meets `90 ms`, but its local allocation is breached.
5. Reset queue wait to `12 ms`, then sweep only deadline through `[60 65 84 90] ms`. The complete
   path stays `[65 65 65 65] ms`; slack becomes `[-5 0 19 25] ms`; allocation reserve becomes
   `[-24 -19 0 6] ms`. Changing a requirement does not make any stage faster.
6. Deliberately omit the `26 ms` coordination stage from budget ownership at `D=60 ms`. The
   incomplete account reports `39 ms` and apparent slack `+21 ms`, while the complete path is
   `65 ms` and misses by `5 ms`.
7. Compare an exact `65 ms` path/deadline tie with a deadline just below `65 ms`. Equality passes;
   the just-smaller deadline fails without an epsilon that silently widens the requirement.
8. Restore baseline inputs in a fresh stateless call, run independent checks, answer one
   interpretation question at a time, and teach back mechanism before consequence.

## Deliberately broken coverage assumption

The broken case violates “a deadline budget is credible even if one causal stage is omitted.” It
keeps the coordination contribution in the real complete-path sum but removes that stage from the
budget ownership mask. The owned stages look healthy: they total `39 ms`, their assigned budgets
total `52 ms`, and both fit the `60 ms` deadline. The missing `26 ms` makes that apparent success a
false-confidence symptom.

An incomplete spreadsheet can therefore show positive slack while the complete causal path misses.
The repair is not to rename the apparent value “end-to-end”; restore coverage, reveal the `65 ms`
complete sum, then change a contribution, allocation, or requirement through an explicit design
decision. This fixture does not choose which system design should change.

## Deadline, timeout, cancellation, rollback, and recovery boundary

The deadline is a scalar classification boundary. An exact complete-path tie passes. A declared
path above `D` means this model cannot guarantee the deadline from those inputs; it does not prove
that every physical transaction misses. The calculation performs no blocking wait and starts no
wall-clock timeout.

There is no cancellation input because no work executes. Deadline failure does not interrupt a
task, remove queued work, cancel a message, or roll back completed stages. All declared
contributions remain visible after classification. This is stateless reevaluation only. A fresh
call after a miss, broken coverage, or
allocation breach demonstrates the restored arithmetic target only; no retry, replay, rollback,
checkpoint restore, or live recovery ran.

## Transparent abstraction and resource bound

Every call evaluates exactly five stages and six cumulative boundary points. Queue wait and
coordination wait are each bounded to `0–1000 ms`; the deadline is bounded to `0–1e6 ms`. Fixed
stages contribute `27 ms`, so the maximum complete-path contribution is `2027 ms`. Work and
storage do not grow with input magnitude.

The model uses base MATLAB scalar/vector arithmetic and fixed arrays. It has no random, global,
persistent, file, storage, timer, system, transport, network, parallel, or background operation.
It does not simulate a queue, run consensus, schedule periodic traffic, assign QoS, perform
admission control, or use physical hardware. Static source checks establish only repository
contracts and independently recomputed reference arithmetic.

## Files

- `model.m` — deterministic complete-path, allocation, coverage, slack, and resource arithmetic.
- `experiment.m` — two complementary baseline views, two isolated sweeps, broken ownership, and
  lifecycle boundaries.
- `interactive.m` — queue wait, coordination wait, deadline, coverage, and reset controls.
- `lesson.m`, `lesson.md`, and `walkthrough.md` — notebook and tutor sequence.
- `checks.md` and `run_checks.m` — independent identities, limits, malformed recovery,
  interpretation, and teach-back.

Static validation and independently recomputed arithmetic do not imply MATLAB-runtime, UI, MATLAB
numerical-fidelity, timing certification, protocol, network, bench, HIL, field, RT1/RT2, Unreal,
signing, deployment, staging, or production validation.
