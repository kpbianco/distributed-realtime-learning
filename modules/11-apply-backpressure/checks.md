# P11 checks: Apply Backpressure

Run `run_checks` from this module folder, or run `run_module_checks('P11')` from the repository
root after P11 is marked implemented. The executable checks independently cover:

- exact baseline demand, admission, service, completion, upstream wait, receiver wait, occupancy,
  pending demand, conservation, ordering, and completion calculations;
- repeatability, accepted integer/logical classes, fractional continuous inputs, and explicit
  completion-before-coincident-admission ties;
- producer-interval sweep `[5 10 20 30] ms` with all other inputs fixed;
- receiver-capacity sweep `[1 2 3 6] messages`, including the invariant `240 ms` completion under overload;
- critical/underloaded limits, zero-capacity always-not-ready behavior, and maximum bounded inputs;
- the deliberately broken ignored-readiness policy, dropped IDs `[6 8 10 12]`, accepted sequence
  gaps, zero upstream wait, and only eight completions;
- exact `10 ms` admission-deadline success, next-demand timeout, just-before timeout, and ordered
  prefix suppression;
- pending message-6 cancellation at `55 ms`, an exact readiness/cancellation tie, accepted-work
  drain without rollback, too-late cancellation at an underloaded receiver, and fresh-call recovery targets;
- stable malformed-input identifiers for empty, text, vector, complex, nonfinite, negative,
  fractional/out-of-range capacity, invalid logical controls, and over-bound values;
- fixed resource counts, bounded loops/storage, presentation isolation, base-MATLAB compatibility,
  and explicit instantaneous-feedback, transport, runtime, and physical-evidence boundaries.

## Interpretation questions

Answer one at a time after observing the relevant view.

1. Why are demand-ready time and receiver-admission time different after message 5?
2. What does a completion credit represent, and why is it not an extra service completion?
3. Why does a completion at the same time as a demand free its slot first in this fixture?
4. What does `280 message-ms` count, and why is it not bandwidth or CPU utilization?
5. How can receiver occupancy remain bounded while upstream pending demand grows?
6. Why does backpressure move overload instead of removing it?
7. Why do all four producer-interval cases complete without loss even though two are overloaded?
8. Why can an underloaded finite batch finish later than an overloaded one?
9. Why does capacity one maximize upstream wait but eliminate receiver queue wait?
10. Why does capacity six reduce upstream wait yet raise receiver queue wait to `100 ms`?
11. Why is completion still `240 ms` across the capacity sweep?
12. Which messages drop when readiness is ignored, and why do dropped messages have no completion latency?
13. Why is zero upstream wait in the broken case a misleading success metric?
14. Why does message 6 succeed at exactly `10 ms` wait while a just-smaller bound rejects it?
15. Why does timeout suppress later demands instead of admitting a sequence gap in the strict policy?
16. What continues to completion after timeout, and what actual timer or task cancellation did not occur?
17. Why can the `55 ms` cancellation remove message 6 but not undo messages `1:5`?
18. When is the same cancellation request too late to affect message 6?
19. What delayed-feedback overshoot is absent because this model uses instantaneous completion credit?
20. What would a real credit/window protocol, retry, or durable recovery path need to add?
21. How do the 12-demand and event-loop bounds differ from a throughput or memory benchmark?
22. What did static/reference checks establish, and what remains unvalidated without MATLAB or hardware?

## Teach-back

In two sentences, answer: “What inputs, observable effects, and failure modes matter when you apply
Backpressure?” Put mechanism first: relate demand cadence, fixed service, completion credit,
finite receiver capacity, and upstream wait. Then explain how capacity, timeout, pending
cancellation, or ignored readiness moves, suppresses, or drops work without claiming actual
blocking, asynchronous cancellation, rollback, retry, MATLAB runtime, or physical validation.
