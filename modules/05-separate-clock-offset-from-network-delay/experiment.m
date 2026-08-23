%% P05 - Separate Clock Offset from Network Delay
experimentFigureTag = 'P05ExperimentFigure';
existingFigures = findall(groot,'Type','figure','Tag',experimentFigureTag);
if ~isempty(existingFigures)
    close(existingFigures);
end

%% Read the sum before looking at syntax
disp('What inputs, observable effects, and failure modes matter when you separate Clock Offset from Network Delay?');
disp(['P04 queue waiting is part of true network delay. Across two clocks, the observable is ' ...
    'receiver timestamp minus sender timestamp = clock offset + network delay.']);
disp('Prediction: can one 10 ms cross-clock timestamp difference identify both terms without an external delay anchor?');

%% Visualize the deterministic baseline metrics
baseline = model(8,7,3,8,0,3);
fprintf(['Baseline: true offset %.0f ms, assumed minimum delay %.0f ms, estimated offset %.0f ms, ' ...
    'observation spread %.0f ms.\n'],baseline.clockOffsetMs, ...
    baseline.assumedMinimumDelayMs,baseline.estimatedClockOffsetMs, ...
    baseline.observedDifferenceSpreadMs);
fprintf(['True network delay spans %.0f to %.0f ms; reconstruction residual is %.3g ms. ' ...
    'Truth curves are simulation-only.\n'],baseline.trueMinimumNetworkDelayMs, ...
    baseline.trueMaximumNetworkDelayMs,baseline.maxAbsReconstructionResidualMs);

figure('Name','P05 baseline cross-clock observation', ...
    'Tag',experimentFigureTag);
plot(baseline.sampleIndex,baseline.observedTimestampDifferenceMs,'o-', ...
    'LineWidth',1.4,'DisplayName','Receiver minus sender timestamp'); hold on;
yline(baseline.minimumObservedDifferenceMs,'k--','LineWidth',1.2, ...
    'DisplayName','Observed lower envelope');
grid on; xlabel('Paired sample index');
ylabel('Cross-clock timestamp difference (ms)');
title('Baseline observable: every point contains offset plus delay');
legend('Location','best');

figure('Name','P05 baseline anchored decomposition', ...
    'Tag',experimentFigureTag);
plot(baseline.sampleIndex,baseline.trueNetworkDelayMs,'o-', ...
    'LineWidth',1.4,'DisplayName','Simulated true network delay'); hold on;
plot(baseline.sampleIndex,baseline.estimatedNetworkDelayMs,'s--', ...
    'LineWidth',1.4,'DisplayName','Delay from anchored separation');
yline(baseline.assumedMinimumDelayMs,'k:','LineWidth',1.2, ...
    'DisplayName','Assumed attainable delay floor');
grid on; xlabel('Paired sample index'); ylabel('One-way network delay (ms)');
title('Baseline changed view: an external floor anchors the absolute split');
legend('Location','best');

expectedQueueDelayMs = [0 2 6 4 8 2 4 0]';
expectedNetworkDelayMs = [3 5 9 7 11 5 7 3]';
expectedObservationMs = [10 12 16 14 18 12 14 10]';
assert(isequal(baseline.variableQueueDelayMs,expectedQueueDelayMs) && ...
    isequal(baseline.trueNetworkDelayMs,expectedNetworkDelayMs), ...
    'Baseline deterministic delay trace changed.');
assert(isequal(baseline.observedTimestampDifferenceMs,expectedObservationMs) && ...
    baseline.estimatedClockOffsetMs == 7, ...
    'Baseline timestamp observation or anchored offset changed.');
assert(isequal(baseline.estimatedNetworkDelayMs,expectedNetworkDelayMs) && ...
    baseline.maxAbsReconstructionResidualMs == 0, ...
    'Baseline anchored decomposition changed.');

%% Sweep 1 - change only signed clock offset
clockOffsetsMs = [-8 0 12];
offsetSweepEstimatedMs = zeros(size(clockOffsetsMs));
offsetSweepMinimumMs = zeros(size(clockOffsetsMs));
offsetSweepSpreadMs = zeros(size(clockOffsetsMs));
offsetSweepDelayMs = zeros(numel(clockOffsetsMs),baseline.sampleCount);
for sweepIndex = 1:numel(clockOffsetsMs)
    swept = model(8,clockOffsetsMs(sweepIndex),3,8,0,3);
    offsetSweepEstimatedMs(sweepIndex) = swept.estimatedClockOffsetMs;
    offsetSweepMinimumMs(sweepIndex) = swept.minimumObservedDifferenceMs;
    offsetSweepSpreadMs(sweepIndex) = swept.observedDifferenceSpreadMs;
    offsetSweepDelayMs(sweepIndex,:) = swept.estimatedNetworkDelayMs';
end

figure('Name','P05 clock-offset sweep estimate', ...
    'Tag',experimentFigureTag);
plot(clockOffsetsMs,offsetSweepEstimatedMs,'o-','LineWidth',1.4, ...
    'DisplayName','Anchored estimate'); hold on;
plot(clockOffsetsMs,clockOffsetsMs,'k--','LineWidth',1.2, ...
    'DisplayName','True offset in simulation');
grid on; xlabel('True receiver-minus-sender clock offset (ms)');
ylabel('Estimated clock offset (ms)');
title('Sweep 1: a valid floor tracks a common timestamp translation');
legend('Location','best');

figure('Name','P05 clock-offset sweep location and spread', ...
    'Tag',experimentFigureTag);
plot(clockOffsetsMs,offsetSweepMinimumMs,'o-','LineWidth',1.4, ...
    'DisplayName','Minimum observed difference'); hold on;
plot(clockOffsetsMs,offsetSweepSpreadMs,'s-','LineWidth',1.4, ...
    'DisplayName','Observed spread');
grid on; xlabel('True receiver-minus-sender clock offset (ms)');
ylabel('Cross-clock timestamp metric (ms)');
title('Sweep 1 changed view: offset moves level, not shape');
legend('Location','best');

assert(isequal(offsetSweepEstimatedMs,clockOffsetsMs) && ...
    isequal(offsetSweepMinimumMs,[-5 3 15]), ...
    'Clock-offset sweep estimate or lower envelope changed.');
assert(isequal(offsetSweepSpreadMs,[8 8 8]) && ...
    all(all(offsetSweepDelayMs == repmat(expectedNetworkDelayMs',3,1))), ...
    'Clock offset must not change spread or recovered network delay.');
disp('Mechanism: a constant clock offset translates every one-way observation equally, so the trace spread is unchanged.');

%% Sweep 2 - reset offset and change only variable queue delay
queuePeaksMs = [0 4 12];
queueSweepEstimatedOffsetMs = zeros(size(queuePeaksMs));
queueSweepSpreadMs = zeros(size(queuePeaksMs));
queueSweepMaximumDelayMs = zeros(size(queuePeaksMs));
for sweepIndex = 1:numel(queuePeaksMs)
    swept = model(8,7,3,queuePeaksMs(sweepIndex),0,3);
    queueSweepEstimatedOffsetMs(sweepIndex) = swept.estimatedClockOffsetMs;
    queueSweepSpreadMs(sweepIndex) = swept.observedDifferenceSpreadMs;
    queueSweepMaximumDelayMs(sweepIndex) = swept.trueMaximumNetworkDelayMs;
end

figure('Name','P05 queue-delay sweep offset estimate', ...
    'Tag',experimentFigureTag);
plot(queuePeaksMs,queueSweepEstimatedOffsetMs,'o-','LineWidth',1.4);
grid on; xlabel('Peak additional queue delay (ms)');
ylabel('Estimated clock offset (ms)');
title('Sweep 2: floor-reaching samples preserve the anchored offset');

figure('Name','P05 queue-delay sweep variation', ...
    'Tag',experimentFigureTag);
plot(queuePeaksMs,queueSweepSpreadMs,'o-','LineWidth',1.4, ...
    'DisplayName','Observed spread'); hold on;
plot(queuePeaksMs,queueSweepMaximumDelayMs,'s-','LineWidth',1.4, ...
    'DisplayName','Simulated maximum network delay');
grid on; xlabel('Peak additional queue delay (ms)');
ylabel('Delay or cross-clock spread (ms)');
title('Sweep 2 changed view: variable queueing changes trace shape');
legend('Location','best');

assert(isequal(queueSweepEstimatedOffsetMs,[7 7 7]) && ...
    isequal(queueSweepSpreadMs,[0 4 12]), ...
    'Queue-delay sweep offset or spread changed.');
assert(isequal(queueSweepMaximumDelayMs,[3 7 15]), ...
    'Queue-delay sweep maximum true delay changed.');
disp('Mechanism: queue variation changes sample-to-sample shape; a floor-reaching sample keeps the lower-envelope anchor fixed.');

%% Deliberately broken case - hidden constant delay aliases with offset
broken = model(8,7,3,8,5,3);
aliased = model(8,12,3,8,0,3);
fprintf(['Broken assumption: a hidden 5 ms common network delay biases the estimate from %.0f to %.0f ms. ' ...
    'A zero residual still cannot reveal the wrong split.\n'],broken.clockOffsetMs, ...
    broken.estimatedClockOffsetMs);

figure('Name','P05 broken minimum-delay anchor observations', ...
    'Tag',experimentFigureTag);
plot(broken.sampleIndex,broken.observedTimestampDifferenceMs,'o-', ...
    'LineWidth',1.5,'DisplayName','7 ms offset + 5 ms hidden delay'); hold on;
plot(aliased.sampleIndex,aliased.observedTimestampDifferenceMs,'s--', ...
    'LineWidth',1.3,'DisplayName','12 ms offset + 0 ms hidden delay');
grid on; xlabel('Paired sample index');
ylabel('Cross-clock timestamp difference (ms)');
title('Deliberately broken anchor: distinct truths are observationally identical');
legend('Location','best');

figure('Name','P05 broken minimum-delay anchor truth', ...
    'Tag',experimentFigureTag);
plot(broken.sampleIndex,broken.trueNetworkDelayMs,'o-', ...
    'LineWidth',1.4,'DisplayName','Simulated true delay with hidden floor'); hold on;
plot(broken.sampleIndex,broken.estimatedNetworkDelayMs,'s--', ...
    'LineWidth',1.4,'DisplayName','Delay inferred from false anchor');
grid on; xlabel('Paired sample index'); ylabel('One-way network delay (ms)');
title('Broken-case symptom: constant network delay is assigned to clock offset');
legend('Location','best');

assert(isequal(broken.observedTimestampDifferenceMs, ...
    aliased.observedTimestampDifferenceMs), ...
    'The broken case and offset alias must have identical one-way observations.');
assert(broken.estimatedClockOffsetMs == 12 && broken.clockOffsetErrorMs == 5 && ...
    all(broken.networkDelayErrorMs == -5), ...
    'The hidden constant delay must bias the two estimated terms equally and oppositely.');
assert(broken.maxAbsReconstructionResidualMs == 0 && ...
    ~broken.minimumDelayAnchorSatisfiedInTruth, ...
    'A perfect fit must coexist with the false-anchor ground-truth diagnostic.');

%% Read and explain the mechanism
disp('Mechanism: z_i = theta + d_i. Offset moves the trace level; variable delay changes its shape under the constant-offset assumption.');
disp('An exact attainable minimum-delay anchor supplies the missing equation. Hidden constant delay aliases with offset even when reconstruction is perfect.');
disp('Teach back what one-way timestamps reveal, what the anchor adds, and why the broken case remains ambiguous.');
