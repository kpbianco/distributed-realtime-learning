# P08 checks: Distribute a Time-Triggered Schedule

Run `run_checks` from this module folder, or run `run_module_checks('P08')` from the repository
root after P08 is marked implemented. The executable checks independently cover:

- exact deterministic clocks, distribution/validation readiness, activation slacks, version map,
  true action windows, cyclic ordering, guard separations, and utilization at baseline;
- repeatability, common-epoch translation, integer-class normalization, and fractional inputs;
- the clock-error sweep `[0 20 40] us` and the independent `90-2E` lower-bound calculation;
- the activation-lead sweep `[600 1000 1500] us`, exact readiness boundary, coherent retain/activate
  decisions, and unchanged coherent timing margin;
- zero-error, zero-distribution-delay, guarantee-boundary, exact and just-beyond readiness/overlap
  boundaries, touching, and maximum-input limits;
- the deliberately broken partial transition, duplicated phase, exact Node C/Node D collision,
  mixed-without-overlap branch, coherent retain-old decision, and later recovery;
- maximum-bound three-way contention, including all three conflicting pairs even though only two
  sorted adjacent transitions are negative, plus distinct pairwise-overlap and channel-overcommit
  totals;
- stable malformed-input identifiers for empty, text, vector, complex, nonfinite, negative,
  over-bound, and invalid activation-policy values;
- recovery after malformed calls, fixed resource counts, presentation/state isolation, and explicit
  exclusive-resource, protocol/runtime/timeout/cancellation/rollback claim boundaries.

## Interpretation questions

Answer one at a time after observing the relevant view.

1. Why does a positive `e_i` make action `i` start early in true time?
2. Why can pairwise clock error consume `2E` of guard when each clock is bounded by `E`?
3. Why does activation lead change readiness slack without changing residual clock offset?
4. Why must true starts be sorted before checking adjacent actions?
5. Why must the last-to-first cycle-wrap gap also be checked?
6. Why may half-open channel occupancy intervals touch at zero separation, while a negative gap
   requests one exclusive shared resource concurrently?
7. At `A=1000 us`, which node is late and why does the coherence policy retain the old map everywhere?
8. Which assumption does `[2 2 2 1]` violate, and why do two maps that are individually
   collision-free at `E=20 us` overlap when mixed?
9. Why does a version number or synchronized clock alone fail to prove coherent activation?
10. What additional messages, failure handling, and evidence would a real atomic rollout require?
11. Which outputs are teaching truth rather than observable values available to a deployed node?
12. Why can coherent versions still collide when residual clock error consumes the complete guard?
13. Why do adjacent negative gaps detect unsafe occupancy but fail to enumerate every pair during
    three-way contention?
14. What did these checks establish, and what remains unvalidated without a MATLAB runtime or hardware?

## Teach-back

In two sentences, answer: “What inputs, observable effects, and failure modes matter when you
distribute a Time-Triggered Schedule?” Put mechanism first: relate `A+s_i-e_i`, `90-2E`, and local
readiness to true action timing on one exclusive shared channel. Then explain why a common
activation epoch plus one coherent schedule version prevents the demonstrated mixed-version
overlap without alone proving clock margin, while stating that the policy is analytical and not a
real commit, timeout, cancellation, rollback, network, or hardware implementation.
