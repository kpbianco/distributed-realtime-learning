# P03 walkthrough: Compare TCP and UDP Behavior

1. Read the guiding question and P02 connection in `README.md`. Identify the P02 frame as the
   application record, not a TCP message boundary.
2. Make one prediction about record 4 after record 3's first attempt is lost.
3. Run `experiment.m` and inspect only the baseline arrival timeline. First follow UDP's missing
   datagram and later arrival; then follow TCP network arrival versus contiguous application
   delivery.
4. Inspect the age view. Name the 800 ms line as an application deadline in milliseconds, not a
   transport cancellation command.
5. Inspect the eventual-versus-on-time count. Explain why TCP can deliver more records eventually
   while delivering fewer than all of them on time.
6. Move only the application-period lever through `[100 200 400]` ms. Observe the changed TCP
   head-of-line wait, then explain how record density interacts with the fixed timeout.
7. Reset the period to 200 ms. Move only the TCP retransmission-timeout lever through
   `[1000 1250 1500]` ms. Confirm that every UDP metric remains fixed before explaining why.
8. Open `interactive.m`. Change one control at a time and use **Reset baseline** between causal
   comparisons. Use lost index zero to inspect the no-loss limit.
9. Inspect the deliberately broken boundary plots. Explain why two 15-byte writes may appear as
   TCP reads of 9 and 21 bytes, then show how P02 sync, length, and checksum parsing recovers both
   frames. Contrast that result with the partial, over-limit, and corrupt fixtures.
10. State the abstraction boundary: established TCP, one timeout-driven successful retransmission,
    a sufficient sender window and out-of-order receiver retention, no real sockets, and no claim
    about congestion control, finite buffers, reordering, packet headers, or wall-clock timeout
    behavior.
11. Run `run_checks` and answer the interpretation prompts in `checks.md` one at a time.
12. Teach back in two sentences: first contrast UDP gap visibility with TCP ordered recovery, then
    state the deadline or framing consequence.
