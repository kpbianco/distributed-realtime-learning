# P13 checks: Budget an End-to-End Deadline

Run `run_checks` from this module folder, or run `run_module_checks('P13')` from the repository
root after P13 is marked implemented. The executable checks independently cover:

- exact baseline stage contributions, allocations, margins, cumulative paths, totals, reserve,
  end-to-end slack, and both accounting identities;
- repeatability, default arguments, accepted integer classes, fractional continuous inputs, fixed
  stage identity/order, and complete ownership;
- queue-wait sweep `[0 6 12 24] ms` with coordination, deadline, all fixed stages, and coverage
  unchanged;
- deadline sweep `[60 65 84 90] ms` with every contribution, allocation, and coverage input fixed;
- the distinction between a local stage-allocation breach and an end-to-end deadline miss;
- the deliberately broken omitted-coordination budget, `39 ms` incomplete account, `+21 ms`
  apparent slack, `26 ms` unowned contribution, `65 ms` complete path, and `-5 ms` real slack;
- a zero-contribution coordination stage that leaves totals and slack identities unchanged when
  omitted but still fails explicit ownership and plan credibility;
- exact path/deadline and stage/allocation ties, just-over and just-before boundaries, zero-wait and
  zero-deadline limits, and direct comparisons without an epsilon-expanded deadline;
- deadline classification without a wall-clock timeout, pending cancellation, rollback, or erased
  contribution; fresh-call recovery targets without retry, replay, or live recovery;
- stable malformed-input identifiers for empty, text, vector, complex, nonfinite, negative,
  invalid logical controls, and over-bound values;
- fixed five-stage/six-boundary resource counts, maximum `2027 ms` contribution, bounded storage,
  presentation isolation, base-MATLAB compatibility, and explicit protocol/runtime/physical limits.

## Interpretation questions

Answer one at a time after observing the relevant view.

1. Which five causal stages form the complete path, and which earlier modules motivate queue and
   coordination contributions?
2. Why does P13 take P12's `26 ms` value as an input instead of claiming to execute consensus?
3. How do `[8 12 10 26 9] ms` become a `65 ms` complete contribution?
4. What is the difference between a stage contribution `c_i` and an allocation `b_i`?
5. Why are stage margins `[2 4 4 6 3] ms` at the baseline?
6. How do `6 ms` of unassigned reserve and `19 ms` of stage margin become `25 ms` of total slack?
7. Why must every causal stage be represented exactly once before that identity is meaningful?
8. Why does adding `6 ms` of queue wait remove exactly `6 ms` of end-to-end slack here?
9. At queue wait `24 ms`, why is the `-8 ms` local margin not also an end-to-end miss?
10. Why should a local allocation breach still be reported when total slack absorbs it?
11. Why does changing `D` affect slack and classification but not the `65 ms` contribution?
12. Why does the complete path meet at `D=65 ms` while the `84 ms` allocation plan does not fit?
13. What becomes true at `D=84 ms` that was not true at `D=65 ms`?
14. Why does exact equality pass both the path/deadline and stage/allocation boundaries?
15. Why would an epsilon added to the comparison silently change the requirement?
16. How does the incomplete budget manufacture `+21 ms` of apparent slack?
17. Which `26 ms` contribution remains in the complete path while missing from ownership?
18. Why is clearing the ownership checkbox not equivalent to skipping coordination execution?
19. What named assumption fails when the incomplete `39 ms` account is called end-to-end?
20. Why does a negative declared slack mean “cannot guarantee” rather than “every transaction missed”?
21. Why is deadline classification not a wall-clock timeout?
22. Why is cancellation not relevant when this evaluator starts no work?
23. What would rollback or recovery require beyond restoring inputs in a fresh arithmetic call?
24. Which periodic scheduling, QoS, and admission-control decisions are intentionally reserved for
    P14–P16?
25. What did static/reference validation establish, and what remains unvalidated without MATLAB,
    a timing analysis, network execution, or hardware?

## Teach-back

In two sentences, answer: “What inputs, observable effects, and failure modes matter when you
budget an End-to-End Deadline?” Put mechanism first: relate complete stage ownership,
`R_e2e=sum(c_i)`, per-stage allocation margin, and deadline reserve. Then explain how queue wait,
deadline choice, a local overrun, or an omitted coordination stage changes what the declared model
can guarantee without claiming a running timeout, cancellation, rollback, recovery, MATLAB
runtime, measured timing, network execution, or physical validation.
