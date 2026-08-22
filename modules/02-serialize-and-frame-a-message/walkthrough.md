# P02 walkthrough: Serialize and Frame a Message

1. Read the guiding question and the byte-layout table in `README.md`.
2. Make one prediction: will sample count, link rate, or both change frame bytes?
3. Run `experiment.m` and inspect only the baseline byte plot first. Identify sync, length, payload,
   and checksum by byte index.
4. Inspect the baseline byte-budget view. Confirm that 11 payload bytes plus four framing bytes make
   a 15-byte frame.
5. Move the sample-count lever. Observe the changed time plot, then explain why each sample adds
   exactly 16 wire bits.
6. Reset to four samples before moving the link-rate lever. Observe that time changes while frame
   bytes and efficiency remain fixed; explain the `T = 8F/R` mechanism.
7. Open `interactive.m`. Change one control at a time and use **Reset baseline** between comparisons.
8. Increase **Extra bytes declared** from zero to two. Observe the receiver change from `accepted`
   to `waiting-for-bytes` and name the violated assumption: declared payload length equals actual
   serialized payload length.
9. Connect the result to P01: serialization occupancy is deterministic, while later propagation,
   jitter, and clock effects can further change observed timing.
10. Run `run_checks` and answer the interpretation prompts in `checks.md` one at a time.
11. Teach back in two sentences: first explain serialization/framing, then state how size, rate, or a
    false length changes the receiver-visible outcome.
