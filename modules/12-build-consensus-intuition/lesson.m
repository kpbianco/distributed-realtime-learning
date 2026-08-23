%% P12 - Build Consensus Intuition
% Guiding question:
% What inputs, observable effects, and failure modes matter when you build Consensus Intuition?
%
% P09 exposed replica lag, P10 preserved one sender's order, and P11
% bounded admission. P12 adds the evidence needed for distinct nodes to
% support one value without pretending this fixture is a full protocol.

%% Read vote timing, threshold, and intersection
disp('A vote is observed after outbound delay, processing, and return delay.');
disp('The q-th distinct vote forms one certificate for the proposal.');
disp('Two q-sized sets among N nodes overlap by at least max(0,2q-N).');
disp('For five nodes, q=3 is the smallest guaranteed-intersecting threshold.');
disp(['Timeout or cancellation closes only this evaluator''s observation ' ...
    'window; later protocol progress is not modeled.']);

%% Observe the baseline, two isolated sweeps, and one broken assumption
experiment;

%% Move one live lever at a time
% Reset between levers. First say whether vote time, evidence count,
% intersection, decision, or timeout changed. Then explain the delay,
% threshold, availability, or cancellation rule that caused it.
interactive;
