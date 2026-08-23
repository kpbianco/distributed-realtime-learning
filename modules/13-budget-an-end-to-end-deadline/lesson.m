%% P13 - Budget an End-to-End Deadline
% Guiding question:
% What inputs, observable effects, and failure modes matter when you budget an End-to-End Deadline?
%
% P04 exposed queue wait, P11 moved overload without erasing it, and P12
% exposed coordination evidence at a finite time. P13 gives every declared
% contribution one owner before comparing the complete path with a deadline.

%% Read complete-path, allocation, and reserve equations
disp('For one sequential transaction, R_e2e = sum(c_i).');
disp('End-to-end slack is D - R_e2e; exact equality meets the deadline.');
disp('Stage margin is b_i - c_i, and reserve is D - sum(b_i).');
disp(['With complete ownership, end-to-end slack equals allocation ' ...
    'reserve plus the sum of stage margins.']);
disp(['A deadline miss is an analytical guarantee failure here, not a ' ...
    'running timeout, cancellation, rollback, or measured event.']);

%% Observe the baseline, two isolated sweeps, and one broken assumption
experiment;

%% Move one live lever at a time
% Reset between levers. First say whether coverage, stage margin,
% allocation reserve, or end-to-end slack changed. Then explain the causal
% stage or requirement comparison that produced the visible difference.
interactive;
