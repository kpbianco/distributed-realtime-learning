# P05 walkthrough: Separate Clock Offset from Network Delay

1. Read the guiding question and P04 connection in `README.md`. Treat P04 queue waiting as one
   component of true network delay.
2. Make the single prediction in `lesson.md`: can one `10 ms` timestamp difference identify both
   clock offset and delay without an anchor?
3. Run `experiment.m` and inspect only the baseline receiver-minus-sender differences. Say aloud
   that every point is `offset + network delay`, in milliseconds.
4. Inspect the anchored decomposition. Confirm the trusted `3 ms` floor makes the `10 ms` minimum
   imply `7 ms` offset, then compare estimated and true network delay.
5. Move only clock offset through `[-8 0 12] ms`. Observe a common translation in every timestamp
   difference while the `8 ms` spread and network-delay trace remain fixed.
6. Reset to `7 ms` offset. Move only queue-delay peak through `[0 4 12] ms`. Observe spread change
   while the lower envelope and offset estimate remain fixed.
7. Explain the mechanism before the conclusion: subtracting a constant changes location, whereas
   changing queue delay changes sample-to-sample shape.
8. Open `interactive.m`. Change one control at a time and use **Reset baseline** before the next
   causal comparison. Treat the assumed floor as external information, not a fitted truth.
9. Add `5 ms` hidden common delay. Compare it with the `12 ms`-offset, zero-hidden-delay alias.
   Their one-way observations overlap exactly even though their true delay traces differ.
10. Identify the violated assumption: the minimum observed sample did not reach the assumed
    `3 ms` network floor. Explain why zero reconstruction residual cannot detect that failure.
11. State the boundary: paired deterministic one-way samples, constant offset, no skew, no loss,
    no NTP exchange, no network I/O, and no MATLAB-runtime or physical evidence claim.
12. Run `run_checks`, answer one prompt from `checks.md` at a time, and teach back in two sentences:
    first the sum equation, then what the anchor adds and what fails when it is false.
