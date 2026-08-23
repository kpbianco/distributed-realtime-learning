%% P05 - Separate Clock Offset from Network Delay
% Guiding question:
% What inputs, observable effects, and failure modes matter when you separate Clock Offset from Network Delay?
%
% P04 made queue delay visible. P05 asks what a receiver can infer when that
% delay is added to the difference between two clocks.

%% Read the one-way timestamp mechanism
disp('Observed receiver-minus-sender time = clock offset + true one-way network delay.');
disp('Variation reveals changing delay; a constant delay component aliases exactly with clock offset.');
disp('A lower-envelope separation is valid only when an external minimum-delay anchor is justified.');

%% Observe the baseline, two isolated sweeps, and one broken assumption
experiment;

%% Move one live lever at a time
% Reset between levers. Explain what stays constant before interpreting what moves.
interactive;
