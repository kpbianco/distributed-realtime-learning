# P02 lesson: Serialize and Frame a Message

## Guiding question

What inputs, observable effects, and failure modes matter when you serialize and Frame a Message?

## Compounds on P01

P01 separated true network delay from clock error. A sender also pays a deterministic cost before
the last bit can leave the interface: every serialized and framing byte consumes link time. P02
makes that `8F/R` term visible before later modules add transport behavior and queues.

## Mental model

Serialization is an agreement, not a MATLAB feature. Sender and receiver must agree on field order,
width, signed representation, and byte order. The baseline payload is:

`type (1 byte) | sequence (2 bytes) | signed samples (2 bytes each)`.

Framing wraps that payload with `sync (1) | declared length (2) | checksum (1)`. For `S` samples:

- payload bytes `P = 3 + 2S`;
- frame bytes `F = P + 4` when the declaration is honest;
- wire bits `B = 8F`;
- serialization time `T_ms = B/R_kbps`;
- payload efficiency `eta = P/F`.

The checksum is chosen so the byte sum after the sync marker is zero modulo 256. That can detect an
accidental change, but it cannot prove who sent the message.

## One prediction before the baseline

Which lever changes the bytes in the frame: sample count, link rate, or both? Hold that prediction
until the first two views appear.

## Baseline observation

Four deterministic samples `[-150 -50 50 150]` serialize to 11 payload bytes. Sync, length, and
checksum make a 15-byte or 120-bit frame. At 1000 kb/s it occupies the link for 0.120 ms, and the
receiver reconstructs the sequence and signed samples exactly.

## Lever 1: sample count

Increase sample count while link rate stays at 1000 kb/s. Each sample adds two bytes, so the frame
grows and serialization time rises linearly. The four framing bytes stay fixed, which improves
payload efficiency for larger messages even though absolute occupancy grows.

## Lever 2: link rate

Reset to four samples, then change only link rate. Frame bytes and efficiency do not move. Time
changes inversely with rate because the same 120 bits cross the link faster or slower.

## Deliberately broken length

Add two to the declared payload length without sending another signed sample. The receiver sees a
structurally possible 13-byte payload declaration and expects a 17-byte frame, but receives 15
bytes. It must not reinterpret the last received byte as a checksum;
it remains in `waiting-for-bytes` until a bounded parser reaches its timeout. A declaration above
this protocol's 131-byte payload limit is rejected immediately instead of waiting or allocating.
The analytical lesson reports either state immediately and never performs a real wait.

## Common mistakes

- A MATLAB numeric value is not yet a portable wire representation.
- Byte order must be explicit; native-memory `typecast` output is not a protocol agreement.
- Link rate changes serialization time, not the number of frame bytes.
- A length prefix is untrusted input and must never drive an unbounded allocation.
- A checksum detects some accidental corruption; it is not encryption or authentication.
- A single sync byte does not guarantee stream resynchronization when the same byte may occur in
  payload; this lesson assumes the receiver is aligned at the first frame byte.

## Completion standard

Run `run_checks`, answer the interpretation questions in `checks.md`, diagnose the exact broken
assumption, and give a two-sentence teach-back: mechanism first, timing or receiver consequence
second.
