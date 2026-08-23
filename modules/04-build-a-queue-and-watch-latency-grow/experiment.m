%% P04 - Build a Queue and Watch Latency Grow
close all; clc;

%% Read the FIFO mechanism before looking at syntax
disp('What inputs, observable effects, and failure modes matter when you build a Queue and Watch Latency Grow?');
disp(['P03 application records now enter one finite FIFO server. An accepted record starts at ' ...
    'max(arrival, prior accepted departure), so waiting accumulates when service is slower than arrivals.']);
disp('Prediction: with a 4 ms arrival period and 6 ms service, which grows first: waiting time or service time?');

%% Visualize the deterministic baseline metrics
baseline = model(12,4,6,4,20,1);
fprintf(['Baseline: %d offered, %d accepted, %d dropped, %d on time, %d late; ' ...
    'nominal utilization %.2f\n'],baseline.messageCount,baseline.acceptedCount, ...
    baseline.droppedCount,baseline.onTimeCount,baseline.lateCount, ...
    baseline.nominalUtilization);
fprintf(['Service stays %.0f ms; FIFO waiting reaches %.0f ms and system latency reaches %.0f ms. ' ...
    'Capacity %d includes the record in service.\n'],baseline.serviceTimeMs, ...
    baseline.maxWaitingTimeMs,baseline.maxSystemLatencyMs,baseline.capacityMessages);

figure('Name','P04 baseline occupancy');
stairs(baseline.recordIndex,baseline.systemOccupancyAfterArrivalCount,'o-', ...
    'LineWidth',1.4,'DisplayName','Unfinished after arrival'); hold on;
yline(baseline.capacityMessages,'k--','LineWidth',1.2, ...
    'DisplayName','Finite system capacity');
scatter(baseline.recordIndex(baseline.droppedMask), ...
    baseline.systemOccupancyAfterArrivalCount(baseline.droppedMask),90,'x', ...
    'LineWidth',1.8,'DisplayName','Tail drop');
grid on; xlabel('Application record index'); ylabel('Unfinished records (count)');
title('Baseline changed view: overload fills the finite FIFO'); legend('Location','best');

figure('Name','P04 baseline waiting and system latency');
plot(baseline.recordIndex,baseline.waitingTimeMs,'o-','LineWidth',1.4, ...
    'DisplayName','FIFO waiting'); hold on;
plot(baseline.recordIndex,baseline.systemLatencyMs,'s-','LineWidth',1.4, ...
    'DisplayName','Arrival-to-departure latency');
yline(baseline.deadlineMs,'k--','LineWidth',1.2,'DisplayName','Application deadline');
scatter(baseline.recordIndex(baseline.droppedMask), ...
    baseline.deadlineMs * ones(baseline.droppedCount,1),90,'x','LineWidth',1.8, ...
    'DisplayName','Dropped: latency undefined');
grid on; xlabel('Application record index'); ylabel('Time (ms)');
title('Baseline changed view: waiting, not service, makes latency grow');
legend('Location','best');

figure('Name','P04 baseline outcome counts');
bar([baseline.acceptedCount baseline.onTimeCount baseline.lateCount baseline.droppedCount]);
set(gca,'XTick',1:4,'XTickLabel',{'Accepted','On time','Late','Dropped'});
grid on; ylabel('Application records (count)');
title('Baseline metrics: accepted does not mean useful before the deadline');

assert(baseline.acceptedCount == 11 && baseline.droppedCount == 1, ...
    'Baseline finite-capacity admission changed.');
assert(baseline.onTimeCount == 8 && baseline.lateCount == 3, ...
    'Baseline deadline classification changed.');
assert(baseline.maxWaitingTimeMs == 18 && baseline.maxSystemLatencyMs == 24, ...
    'Baseline FIFO latency anchors changed.');

%% Sweep 1 - change only the arrival period
arrivalPeriodsMs = [4 6 8];
arrivalSweepUtilization = zeros(size(arrivalPeriodsMs));
arrivalSweepOnTime = zeros(size(arrivalPeriodsMs));
arrivalSweepDropped = zeros(size(arrivalPeriodsMs));
arrivalSweepMaxLatencyMs = zeros(size(arrivalPeriodsMs));
for sweepIndex = 1:numel(arrivalPeriodsMs)
    swept = model(12,arrivalPeriodsMs(sweepIndex),6,4,20,1);
    arrivalSweepUtilization(sweepIndex) = swept.nominalUtilization;
    arrivalSweepOnTime(sweepIndex) = swept.onTimeCount;
    arrivalSweepDropped(sweepIndex) = swept.droppedCount;
    arrivalSweepMaxLatencyMs(sweepIndex) = swept.maxSystemLatencyMs;
end

figure('Name','P04 arrival-period sweep outcomes');
plot(arrivalPeriodsMs,arrivalSweepOnTime,'o-','LineWidth',1.4, ...
    'DisplayName','On time'); hold on;
plot(arrivalPeriodsMs,arrivalSweepDropped,'s-','LineWidth',1.4, ...
    'DisplayName','Dropped');
grid on; xlabel('Arrival period (ms)'); ylabel('Application records (count)');
title('Sweep 1: slower arrivals let the fixed server drain'); legend('Location','best');

figure('Name','P04 arrival-period sweep latency');
plot(arrivalPeriodsMs,arrivalSweepMaxLatencyMs,'o-','LineWidth',1.4);
grid on; xlabel('Arrival period (ms)'); ylabel('Maximum accepted latency (ms)');
title('Sweep 1 changed view: utilization crosses one');

assert(max(abs(arrivalSweepUtilization - [1.5 1 0.75])) < 1e-12, ...
    'Arrival-period sweep utilization changed.');
assert(isequal(arrivalSweepOnTime,[8 12 12]) && ...
    isequal(arrivalSweepDropped,[1 0 0]), ...
    'Arrival-period sweep outcome counts changed.');
assert(isequal(arrivalSweepMaxLatencyMs,[24 6 6]), ...
    'Arrival-period sweep latency changed.');
disp('Mechanism: increasing the period lowers offered work; at or below one service-time per period, each periodic arrival finds a free server.');

%% Sweep 2 - reset the period and change only finite capacity
capacityValues = [1 2 4 8];
capacitySweepOnTime = zeros(size(capacityValues));
capacitySweepDropped = zeros(size(capacityValues));
capacitySweepLate = zeros(size(capacityValues));
capacitySweepMaxLatencyMs = zeros(size(capacityValues));
for sweepIndex = 1:numel(capacityValues)
    swept = model(12,4,6,capacityValues(sweepIndex),20,1);
    capacitySweepOnTime(sweepIndex) = swept.onTimeCount;
    capacitySweepDropped(sweepIndex) = swept.droppedCount;
    capacitySweepLate(sweepIndex) = swept.lateCount;
    capacitySweepMaxLatencyMs(sweepIndex) = swept.maxSystemLatencyMs;
end

figure('Name','P04 capacity sweep outcomes');
plot(capacityValues,capacitySweepOnTime,'o-','LineWidth',1.4, ...
    'DisplayName','On time'); hold on;
plot(capacityValues,capacitySweepLate,'d-','LineWidth',1.4, ...
    'DisplayName','Accepted but late');
plot(capacityValues,capacitySweepDropped,'s-','LineWidth',1.4, ...
    'DisplayName','Dropped');
grid on; xlabel('System capacity including service (records)');
ylabel('Application records (count)');
title('Sweep 2: capacity trades drops for queued and sometimes stale work');
legend('Location','best');

figure('Name','P04 capacity sweep latency');
plot(capacityValues,capacitySweepMaxLatencyMs,'o-','LineWidth',1.4);
grid on; xlabel('System capacity including service (records)');
ylabel('Maximum accepted latency (ms)');
title('Sweep 2 changed view: storage does not add service rate');

assert(isequal(capacitySweepOnTime,[6 9 8 8]), ...
    'Capacity sweep on-time counts changed.');
assert(isequal(capacitySweepLate,[0 0 3 4]) && ...
    isequal(capacitySweepDropped,[6 3 1 0]), ...
    'Capacity sweep late/drop tradeoff changed.');
assert(isequal(capacitySweepMaxLatencyMs,[6 12 24 28]), ...
    'Capacity sweep latency changed.');
disp('Mechanism: a larger buffer can convert a drop into a later departure, but it cannot make a 6 ms server complete work faster.');

%% Deliberately broken case - average load hides a P03 release burst
smooth = model(8,10,6,8,15,1);
broken = model(8,10,6,8,15,4);
fprintf(['Broken assumption: utilization %.2f is below one in both cases, yet the P03-style ' ...
    'four-record release burst raises maximum latency from %.0f to %.0f ms and creates %d misses.\n'], ...
    broken.nominalUtilization,smooth.maxSystemLatencyMs,broken.maxSystemLatencyMs, ...
    broken.lateCount);

figure('Name','P04 broken average-rate assumption arrivals');
plot(smooth.recordIndex,smooth.arrivalTimeMs,'o-','LineWidth',1.4, ...
    'DisplayName','Evenly spaced arrivals'); hold on;
plot(broken.recordIndex,broken.arrivalTimeMs,'s--','LineWidth',1.4, ...
    'DisplayName','P03 contiguous release burst');
grid on; xlabel('Application record index'); ylabel('Queue arrival time (ms)');
title('Deliberately broken assumption: equal average rate, different arrival shape');
legend('Location','best');

figure('Name','P04 broken average-rate assumption latency');
plot(smooth.recordIndex,smooth.systemLatencyMs,'o-','LineWidth',1.4, ...
    'DisplayName','Evenly spaced latency'); hold on;
plot(broken.recordIndex,broken.systemLatencyMs,'s-','LineWidth',1.4, ...
    'DisplayName','Burst latency');
yline(broken.deadlineMs,'k--','LineWidth',1.2,'DisplayName','Application deadline');
grid on; xlabel('Application record index'); ylabel('Arrival-to-departure latency (ms)');
title('Broken-case symptom: a transient queue misses deadlines below average capacity');
legend('Location','best');

assert(smooth.nominalUtilization == broken.nominalUtilization && ...
    smooth.nominalUtilization < 1,'The broken case must preserve subcritical average load.');
assert(smooth.lateCount == 0 && broken.lateCount == 3 && ...
    smooth.maxSystemLatencyMs == 6 && broken.maxSystemLatencyMs == 24, ...
    'The P03 release burst symptom changed.');

%% Read and explain the mechanism
disp('Mechanism: for every admitted record, start=max(arrival, prior departure), wait=start-arrival, and system latency=wait+service.');
disp('A finite capacity bounds unfinished work by dropping arrivals; a deadline classifies accepted results but does not cancel service.');
disp('Teach back why utilization, arrival burstiness, finite capacity, and a deadline answer different questions.');
