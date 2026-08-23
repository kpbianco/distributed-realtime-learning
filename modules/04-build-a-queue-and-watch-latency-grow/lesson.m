%% P04 - Build a Queue and Watch Latency Grow
% Guiding question:
% What inputs, observable effects, and failure modes matter when you build a Queue and Watch Latency Grow?
%
% P03 made transport delivery timing visible. P04 adds a finite FIFO stage:
% arrival shape and service demand determine waiting, while capacity decides
% whether excess work waits or drops.

%% Read the queue mechanism
disp('For an admitted record: start=max(arrival, prior admitted departure).');
disp('Waiting=start-arrival; system latency=waiting+fixed service.');
disp('Capacity includes one record in service. A deadline classifies usefulness but does not cancel work.');

%% Observe the baseline, two isolated sweeps, and one broken case
experiment;

%% Move one live lever at a time
% Reset between levers. Explain the FIFO mechanism before judging the outcome.
interactive;
