%% P06 - Model NTP-Style Exchange
% Guiding question:
% What inputs, observable effects, and failure modes matter when you model NTP-Style Exchange?
%
% P05 exposed one-way offset/delay ambiguity. P06 adds a request and reply
% with four local timestamps, while keeping path symmetry visible as an
% assumption rather than a measured fact.

%% Read the four-timestamp mechanism
disp('Use theta = server clock - client clock. Record T1/T4 at the client and T2/T3 at the server.');
disp('theta_hat = ((T2-T1) + (T3-T4))/2; delta_hat = (T4-T1) - (T3-T2).');
disp('Server residence cancels from both estimates; path asymmetry contributes half its signed value to offset error.');

%% Observe the baseline, two isolated sweeps, and one broken assumption
experiment;

%% Move one live lever at a time
% Reset between levers. Explain which interval is held fixed before
% interpreting the changed view.
interactive;
