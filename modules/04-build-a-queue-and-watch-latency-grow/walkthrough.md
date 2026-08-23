# P04 walkthrough: Build a Queue and Watch Latency Grow

1. Read the guiding question and the P03 connection in `README.md`. Treat transport delivery as
   queue arrival; do not add queue waiting to records that never arrive.
2. Make the single prediction in `lesson.md`: when `4 ms` arrivals meet `6 ms` service, which
   latency component changes?
3. Run `experiment.m` and inspect only baseline occupancy. Name the capacity as four unfinished
   records including one in service, and identify the record that tail-drops.
4. Inspect waiting and system latency in milliseconds. Confirm that service stays `6 ms`, waiting
   grows, dropped latency remains undefined, and the `20 ms` deadline only classifies accepted work.
5. Inspect accepted, on-time, late, and dropped record counts. Explain why none of those labels can
   safely substitute for the others.
6. Move only arrival period through `[4 6 8] ms`. Follow utilization `[1.5 1 0.75]`, then connect
   the disappearance of waiting to the FIFO start recurrence and departure-before-arrival tie rule.
7. Reset to `4 ms`. Move only total capacity through `[1 2 4 8]` records. Explain why drops fall
   while maximum accepted latency rises even though service rate never changes.
8. Open `interactive.m`. Change one control at a time and use **Reset baseline** before each causal
   comparison. Toggle the P03 release burst only after restoring the underloaded `10 ms` period and
   `6 ms` service case.
9. Compare the smooth and deliberately broken release-burst views. Both have nominal utilization
   `0.6`; only the arrival shape changes. Identify transient FIFO waiting as the cause of three
   `15 ms` deadline misses.
10. State the abstraction boundary: deterministic bounded FIFO, one fixed-rate server, tail drop,
    no retry, no wall-clock wait, and no claim about MATLAB runtime, threads, sockets, schedulers,
    real buffers, timeout, or cancellation.
11. Run `run_checks` and answer the interpretation prompts in `checks.md` one at a time.
12. Teach back in two sentences: first explain `start=max(arrival, prior departure)` and then state
    how arrival shape, service, capacity, and deadline determine waiting, drops, and usefulness.
