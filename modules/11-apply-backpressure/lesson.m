%% P11 - Apply Backpressure
% Guiding question:
% What inputs, observable effects, and failure modes matter when you apply Backpressure?
%
% P10 showed why finite receiver storage cannot accept arbitrary later work.
% P11 makes receiver readiness visible to one ordered producer.

%% Read the demand, admission, completion-credit mechanism
disp('Demand i becomes ready at R_i = (i-1)P.');
disp('A completion returns one finite receiver slot before coincident admission.');
disp('Backpressure holds demand upstream until a slot opens, timeout, or pending cancellation.');
disp('It bounds receiver occupancy; it does not create consumer service capacity.');

%% Observe the baseline, two isolated sweeps, and one broken assumption
experiment;

%% Move one live lever at a time
% Reset between levers. First name whether demand, admission, completion,
% receiver occupancy, upstream pending work, or failure changed. Then explain
% which readiness, capacity, service, timeout, or cancellation rule caused it.
interactive;
