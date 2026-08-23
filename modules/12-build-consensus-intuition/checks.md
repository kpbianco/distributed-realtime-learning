# P12 checks: Build Consensus Intuition

Run `run_checks` from this module folder, or run `run_module_checks('P12')` from the repository
root after P12 is marked implemented. The executable checks independently cover:

- exact baseline outbound, processing, return, potential vote, cumulative evidence, certificate,
  decision, intersection, and availability calculations;
- repeatability, accepted integer/logical classes, fractional continuous inputs, deterministic
  lower-node-ID vote-time ties, and evidence-before-exact-boundary arbitration;
- delay-scale sweep `[0 0.5 1 2]` with quorum, timeout, availability, and cancellation fixed;
- quorum-size sweep `[2 3 4 5]` with timing and every other input fixed;
- zero-delay processing limit, maximum bounded inputs, reachable four-of-five operation, and
  unreachable all-five operation;
- the deliberately broken `q=2` threshold, disjoint certificates `{1,2}` and `{4,5}`, zero
  guaranteed intersection, and possible conflicting values;
- exact timeout success at `38 ms`, just-before timeout with partial votes, zero-timeout limits,
  and the distinction between missing evidence and diagnosed failure;
- pending cancellation at `20 ms`, exact vote/cancellation and cancellation/timeout ties,
  timeout before later cancellation, too-late cancellation, local observed-vote/no-certificate
  behavior, visible potential later evidence, no rollback, and fresh-call recovery targets;
- stable malformed-input identifiers for empty, text, vector, complex, nonfinite, negative,
  fractional/out-of-range quorum, invalid logical controls, and over-bound values;
- fixed resource counts, bounded loops/storage, presentation isolation, base-MATLAB compatibility,
  and explicit consensus-protocol, runtime, network, storage, and physical-evidence boundaries.

## Interpretation questions

Answer one at a time after observing the relevant view.

1. Which three events form the baseline certificate, and why does the third fix latency?
2. Why are potential votes at `38` and `62 ms` unnecessary for the baseline response?
3. What remains at scale zero, and why is the decision latency `2 ms` rather than zero?
4. Why is a vote count about distinct eligible nodes rather than packet count?
5. What does `max(0,2q-N)` measure?
6. Why do all two three-node sets among five nodes intersect?
7. Why does intersection need a one-vote-per-node-per-term discipline?
8. Why does changing delay scale move latency but not minimum quorum intersection?
9. Why does increasing `q` raise both decision latency and guaranteed overlap here?
10. Why does increasing `q` reduce unavailable-follower tolerance when the fixed proposer remains
    online, and why does that say nothing about proposer failure?
11. Why is `q=3` the smallest majority threshold for five fixed nodes?
12. How can `{1,2}` and `{4,5}` both reach `q=2` without sharing a voter?
13. What named assumption fails when the broken case treats `q=2` as safe agreement?
14. Why is the broken certificate view not evidence that a partition protocol ran?
15. Why does a vote at exactly `38 ms` beat a `38 ms` timeout?
16. Why does a just-smaller timeout leave this evaluator without a certificate after three votes,
    and why is that not proof of permanent global non-decision?
17. Why does a timeout not prove Node 4 or Node 5 crashed?
18. Why can `q=5` be safe yet unavailable when Node 5 is offline?
19. Why does cancellation at `20 ms` affect baseline `q=3` but not baseline `q=2`?
20. Why can a vote at the cancellation instant complete the certificate?
21. When timeout and cancellation tie without a certificate, why does this fixture classify the
    local result as cancellation?
22. What potential evidence remains visible after timeout or pending cancellation, and what can
    this evaluator not conclude about later protocol progress?
23. What would durable one-vote enforcement require beyond this arithmetic fixture?
24. Which Raft/Paxos/election/log/application/reconfiguration behaviors are outside this model?
25. What did static/reference checks establish, and what remains unvalidated without MATLAB or hardware?

## Teach-back

In two sentences, answer: “What inputs, observable effects, and failure modes matter when you build
Consensus Intuition?” Put mechanism first: relate round-trip vote timing, the q-th distinct vote,
and guaranteed quorum intersection. Then explain how threshold, unavailable followers with the
fixed proposer online, timeout, or pending cancellation changes local evidence without claiming
permanent global non-decision, full consensus, rollback, recovery, MATLAB runtime, network
execution, or physical validation.
