# Lesson: See Delay, Jitter, and Clock Skew Distort Timestamps

## Guiding question

How do network delay, jitter, clock offset, and clock skew distort one-way timing?

## Mental model

A timestamp combines event time, clock error, and network delay. Without synchronization, one measured latency can look like another even when the physical message path is unchanged.

## What to manipulate

Use `interactive.m`. Change one lever at a time before combining effects.

## First observation

Increase jitter and watch the latency distribution widen. Add clock skew and watch timestamp error grow with elapsed time even though actual network delay has no trend.

## Common mistakes

- Subtracting two remote timestamps does not automatically produce one-way latency.
- Clock offset and frequency skew are different errors.
- Low average latency does not guarantee a real-time deadline.

## Completion standard

The learner can explain the baseline, identify what each lever changes, diagnose the deliberately broken case, and pass `run_checks.m`.
