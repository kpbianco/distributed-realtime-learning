function run_checks
%RUN_CHECKS Independent deterministic checks for P11 backpressure.

%% Baseline identities and repeatability
baseline = model();
repeated = model(10,20,3,200,true,false);
typed = model(int32(10),single(20),uint8(3), ...
    single(200),uint8(1),int8(0));
assert(isequaln(baseline,repeated));
assert(isequaln(baseline,typed));
assert(baseline.producerIntervalMs == 10);
assert(baseline.serviceTimeMs == 20);
assert(baseline.receiverCapacityMessages == 3);
assert(baseline.maxBackpressureWaitMs == 200);
assert(baseline.useBackpressure);
assert(~baseline.cancelMessageSixWhileWaiting);
assert(baseline.messageCount == 12);
assert(isequal(baseline.messageId,1:12));

expectedReadyTimeMs = 0:10:110;
expectedAdmissionTimeMs = ...
    [0 10 20 30 40 60 80 100 120 140 160 180];
expectedServiceStartTimeMs = 0:20:220;
expectedCompletionTimeMs = 20:20:240;
expectedUpstreamWaitMs = [0 0 0 0 0 10 20 30 40 50 60 70];
expectedReceiverQueueWaitMs = ...
    [0 10 20 30 40 40 40 40 40 40 40 40];
expectedReceiverResidenceTimeMs = expectedReceiverQueueWaitMs + 20;
expectedEndToEndTimeMs = ...
    expectedUpstreamWaitMs + expectedReceiverResidenceTimeMs;
expectedOccupancyAfterAdmission = [1 2 2 3 3 3 3 3 3 3 3 3];
assert(isequal(baseline.demandReadyTimeMs,expectedReadyTimeMs));
assert(isequal(baseline.admissionTimeMs,expectedAdmissionTimeMs));
assert(isequal(baseline.serviceStartTimeMs,expectedServiceStartTimeMs));
assert(isequal(baseline.completionTimeMs,expectedCompletionTimeMs));
assert(isequal(baseline.decisionTimeMs,expectedAdmissionTimeMs));
assert(isequal(baseline.upstreamWaitUntilDecisionMs, ...
    expectedUpstreamWaitMs));
assert(isequal(baseline.receiverQueueWaitMs, ...
    expectedReceiverQueueWaitMs));
assert(isequal(baseline.receiverResidenceTimeMs, ...
    expectedReceiverResidenceTimeMs));
assert(isequal(baseline.endToEndTimeMs,expectedEndToEndTimeMs));
assert(isequal(baseline.receiverOccupancyAfterAdmission, ...
    expectedOccupancyAfterAdmission));
assert(all(baseline.admittedMask));
assert(~any(baseline.failedMask));
assert(isequal(baseline.admittedMessageIds,1:12));
assert(isequal(baseline.completedMessageIds,1:12));
assert(baseline.admittedCount == 12);
assert(baseline.completedCount == 12);
assert(baseline.failedCount == 0);
assert(baseline.backpressuredMessageCount == 7);
assert(baseline.admittedAfterWaitingCount == 7);
assert(baseline.totalUpstreamWaitMessageMs == 280);
assert(baseline.maxUpstreamWaitMs == 70);
assert(baseline.totalReceiverQueueWaitMessageMs == 380);
assert(baseline.maxReceiverQueueWaitMs == 40);
assert(baseline.maxReceiverResidenceTimeMs == 60);
assert(baseline.maxEndToEndTimeMs == 130);
assert(baseline.completionTimeOfBatchMs == 240);
assert(baseline.receiverHighWaterMessages == 3);
assert(baseline.peakUpstreamPendingMessages == 4);
assert(baseline.losslessCompletion);
assert(baseline.allDemandAccountedFor);
assert(baseline.receiverCapacityRespected);
assert(baseline.admissionOrderPreserved);
assert(baseline.completionOrderPreserved);
assert(baseline.acceptedPrefixPreserved);
assert(all(diff(baseline.admissionTimeMs(baseline.admittedMask)) >= 0));
assert(all(diff(baseline.completionTimeMs(baseline.admittedMask)) > 0));
assert(baseline.nominalOfferedRateMessagesPerSecond == 100);
assert(baseline.serviceRateMessagesPerSecond == 50);
assert(baseline.offeredLoadRatio == 2);
assert(baseline.effectiveCompletionRateMessagesPerSecond == 50);
assert(strcmp(baseline.outcome,'lossless-backpressure'));
assert(~baseline.streamStopped);
assert(strcmp(baseline.streamStopReason,'none'));

% Independent flow conservation at every retained observation instant.
assert(isequal(baseline.receiverOccupancyMessages, ...
    baseline.admittedCumulative - baseline.completedCumulative));
assert(isequal(baseline.upstreamPendingMessages, ...
    baseline.offeredCumulative - baseline.admittedCumulative - ...
    baseline.failedCumulative));
assert(baseline.offeredCumulative(end) == 12);
assert(baseline.admittedCumulative(end) == 12);
assert(baseline.completedCumulative(end) == 12);
assert(baseline.failedCumulative(end) == 0);
assert(all(baseline.receiverOccupancyMessages <= 3));
assert(isequal(baseline.endToEndTimeMs, ...
    baseline.upstreamWaitUntilDecisionMs + ...
    baseline.receiverQueueWaitMs + baseline.serviceTimeMs));
assert(all(diff(baseline.completionTimeMs) == 20));

fractional = model(7.5,12.5,4,37.5,true,false);
assert(fractional.producerIntervalMs == 7.5);
assert(fractional.serviceTimeMs == 12.5);
assert(fractional.maxBackpressureWaitMs == 37.5);
assert(fractional.allDemandAccountedFor);
assert(fractional.receiverCapacityRespected);
assert(fractional.admissionOrderPreserved);

%% Sweep 1: producer interval only
producerIntervalsMs = [5 10 20 30];
intervalTotalUpstreamWait = zeros(size(producerIntervalsMs));
intervalMaxUpstreamWait = zeros(size(producerIntervalsMs));
intervalReceiverHighWater = zeros(size(producerIntervalsMs));
intervalCompletionTimeMs = zeros(size(producerIntervalsMs));
intervalCompletedCount = zeros(size(producerIntervalsMs));
for caseIndex = 1:numel(producerIntervalsMs)
    current = model(producerIntervalsMs(caseIndex),20,3,200,true,false);
    assert(current.serviceTimeMs == 20);
    assert(current.receiverCapacityMessages == 3);
    assert(current.maxBackpressureWaitMs == 200);
    assert(current.useBackpressure);
    assert(~current.cancelMessageSixWhileWaiting);
    assert(current.losslessCompletion);
    assert(current.receiverCapacityRespected);
    intervalTotalUpstreamWait(caseIndex) = ...
        current.totalUpstreamWaitMessageMs;
    intervalMaxUpstreamWait(caseIndex) = current.maxUpstreamWaitMs;
    intervalReceiverHighWater(caseIndex) = ...
        current.receiverHighWaterMessages;
    intervalCompletionTimeMs(caseIndex) = ...
        current.completionTimeOfBatchMs;
    intervalCompletedCount(caseIndex) = current.completedCount;
end
assert(isequal(intervalTotalUpstreamWait,[585 280 0 0]));
assert(isequal(intervalMaxUpstreamWait,[125 70 0 0]));
assert(isequal(intervalReceiverHighWater,[3 3 1 1]));
assert(isequal(intervalCompletionTimeMs,[240 240 240 350]));
assert(isequal(intervalCompletedCount,[12 12 12 12]));

%% Sweep 2: receiver capacity only
receiverCapacities = [1 2 3 6];
capacityTotalUpstreamWait = zeros(size(receiverCapacities));
capacityMaxUpstreamWait = zeros(size(receiverCapacities));
capacityMaxReceiverWait = zeros(size(receiverCapacities));
capacityCompletionTimeMs = zeros(size(receiverCapacities));
capacityHighWater = zeros(size(receiverCapacities));
for caseIndex = 1:numel(receiverCapacities)
    current = model(10,20,receiverCapacities(caseIndex), ...
        200,true,false);
    assert(current.producerIntervalMs == 10);
    assert(current.serviceTimeMs == 20);
    assert(current.maxBackpressureWaitMs == 200);
    assert(current.losslessCompletion);
    assert(current.receiverCapacityRespected);
    capacityTotalUpstreamWait(caseIndex) = ...
        current.totalUpstreamWaitMessageMs;
    capacityMaxUpstreamWait(caseIndex) = current.maxUpstreamWaitMs;
    capacityMaxReceiverWait(caseIndex) = ...
        current.maxReceiverQueueWaitMs;
    capacityCompletionTimeMs(caseIndex) = ...
        current.completionTimeOfBatchMs;
    capacityHighWater(caseIndex) = current.receiverHighWaterMessages;
end
assert(isequal(capacityTotalUpstreamWait,[660 450 280 10]));
assert(isequal(capacityMaxUpstreamWait,[110 90 70 10]));
assert(isequal(capacityMaxReceiverWait,[0 20 40 100]));
assert(isequal(capacityCompletionTimeMs,[240 240 240 240]));
assert(isequal(capacityHighWater,[1 2 3 6]));

%% Limiting cases and explicit tie rule
critical = model(20,20,1,0,true,false);
assert(critical.losslessCompletion);
assert(all(critical.upstreamWaitUntilDecisionMs == 0));
assert(all(critical.receiverQueueWaitMs == 0));
assert(critical.receiverHighWaterMessages == 1);
assert(critical.completionTimeOfBatchMs == 240);
assert(critical.completionCreditBeforeCoincidentAdmission);

underloaded = model(30,20,1,0,true,false);
assert(underloaded.losslessCompletion);
assert(all(underloaded.upstreamWaitUntilDecisionMs == 0));
assert(all(underloaded.receiverQueueWaitMs == 0));
assert(underloaded.receiverHighWaterMessages == 1);
assert(underloaded.completionTimeOfBatchMs == 350);

capacityAboveDemand = model(10,20,12,200,true,false);
assert(capacityAboveDemand.losslessCompletion);
assert(all(capacityAboveDemand.upstreamWaitUntilDecisionMs == 0));
assert(capacityAboveDemand.completionTimeOfBatchMs == 240);
assert(capacityAboveDemand.maxReceiverQueueWaitMs == 110);
assert(capacityAboveDemand.receiverCapacityRespected);

zeroCapacity = model(10,20,0,20,true,false);
assert(zeroCapacity.admittedCount == 0);
assert(zeroCapacity.completedCount == 0);
assert(zeroCapacity.timedOutCount == 1);
assert(zeroCapacity.suppressedCount == 11);
assert(zeroCapacity.failedCount == 12);
assert(zeroCapacity.timedOutMask(1));
assert(all(zeroCapacity.suppressedMask(2:12)));
assert(zeroCapacity.streamStopped);
assert(zeroCapacity.streamStopTimeMs == 20);
assert(strcmp(zeroCapacity.streamStopReason,'upstream-timeout'));
assert(zeroCapacity.receiverHighWaterMessages == 0);
assert(zeroCapacity.receiverCapacityRespected);
assert(zeroCapacity.acceptedPrefixPreserved);

bounded = model(1,1000,12,1e6,true,false);
assert(bounded.losslessCompletion);
assert(isequal(bounded.demandReadyTimeMs,0:11));
assert(isequal(bounded.admissionTimeMs,0:11));
assert(isequal(bounded.completionTimeMs,1000:1000:12000));
assert(bounded.receiverHighWaterMessages == 12);
assert(bounded.observationEventCount <= bounded.maxObservationEventCount);
assert(bounded.admissionComparisonCount <= ...
    bounded.maxAdmissionComparisonCount);
assert(bounded.observationEndTimeMs <= bounded.maxDerivedTimeMs);

% Capacity one and service much slower than demand force every prior
% completion comparison before each new admission. This realizes the
% analytical maximum sum(n*(n+2),n=0:11) = 638.
worstCaseComparisons = model(1,1000,1,1e6,true,false);
assert(worstCaseComparisons.losslessCompletion);
assert(isequal(worstCaseComparisons.admissionTimeMs,0:1000:11000));
assert(worstCaseComparisons.receiverHighWaterMessages == 1);
assert(worstCaseComparisons.admissionComparisonCount == 638);
assert(worstCaseComparisons.maxAdmissionComparisonCount == 638);
assert(worstCaseComparisons.admissionComparisonCount == ...
    worstCaseComparisons.maxAdmissionComparisonCount);
assert(worstCaseComparisons.observationEventCount <= ...
    worstCaseComparisons.maxObservationEventCount);
assert(worstCaseComparisons.observationEndTimeMs <= ...
    worstCaseComparisons.maxDerivedTimeMs);

%% Deliberately broken readiness policy
broken = model(10,20,3,200,false,false);
assert(~broken.useBackpressure);
assert(isequal(broken.admittedMessageIds,[1 2 3 4 5 7 9 11]));
assert(isequal(find(broken.droppedMask),[6 8 10 12]));
assert(broken.admittedCount == 8);
assert(broken.completedCount == 8);
assert(broken.droppedCount == 4);
assert(broken.timedOutCount == 0);
assert(broken.canceledCount == 0);
assert(broken.suppressedCount == 0);
assert(broken.failedCount == 4);
assert(broken.totalUpstreamWaitMessageMs == 0);
assert(broken.maxUpstreamWaitMs == 0);
assert(broken.receiverHighWaterMessages == 3);
assert(broken.receiverCapacityRespected);
assert(broken.admissionOrderPreserved);
assert(broken.completionOrderPreserved);
assert(all(diff(broken.admissionTimeMs(broken.admittedMask)) > 0));
assert(all(diff(broken.completionTimeMs(broken.admittedMask)) > 0));
assert(~broken.acceptedPrefixPreserved);
assert(~broken.losslessCompletion);
assert(strcmp(broken.outcome,'readiness-ignored-with-drops'));
assert(isequaln(broken.admissionTimeMs, ...
    [0 10 20 30 40 nan 60 nan 80 nan 100 nan]));
assert(isequaln(broken.completionTimeMs, ...
    [20 40 60 80 100 nan 120 nan 140 nan 160 nan]));
assert(isequal(broken.receiverOccupancyMessages, ...
    broken.admittedCumulative - broken.completedCumulative));
assert(isequal(broken.upstreamPendingMessages, ...
    zeros(size(broken.upstreamPendingMessages))));
assert(isequal(broken.offeredCumulative - ...
    broken.admittedCumulative - broken.failedCumulative, ...
    zeros(size(broken.offeredCumulative))));

brokenUnderload = model(20,20,1,200,false,false);
assert(brokenUnderload.losslessCompletion);
assert(brokenUnderload.droppedCount == 0);
assert(strcmp(brokenUnderload.outcome,'readiness-ignored-no-drop'));

%% Timeout, cancellation, rollback, and recovery
exactWaitBoundary = model(10,20,3,10,true,false);
assert(isequal(exactWaitBoundary.admittedMessageIds,1:6));
assert(exactWaitBoundary.admissionTimeMs(6) == 60);
assert(exactWaitBoundary.upstreamWaitUntilDecisionMs(6) == 10);
assert(exactWaitBoundary.timedOutMask(7));
assert(exactWaitBoundary.streamStopTimeMs == 70);
assert(all(exactWaitBoundary.suppressedMask(8:12)));
assert(exactWaitBoundary.completedCount == 6);
assert(exactWaitBoundary.completionTimeOfBatchMs == 120);
assert(exactWaitBoundary.acceptedPrefixPreserved);
assert(strcmp(exactWaitBoundary.outcome,'backpressure-timeout'));

justBeforeWaitBoundary = model(10,20,3,10 - 1e-12,true,false);
assert(isequal(justBeforeWaitBoundary.admittedMessageIds,1:5));
assert(justBeforeWaitBoundary.timedOutMask(6));
assert(justBeforeWaitBoundary.streamStopTimeMs < 60);
assert(all(justBeforeWaitBoundary.suppressedMask(7:12)));
assert(justBeforeWaitBoundary.completedCount == 5);
assert(justBeforeWaitBoundary.completionTimeOfBatchMs == 100);
assert(justBeforeWaitBoundary.acceptedPrefixPreserved);

zeroWait = model(10,20,3,0,true,false);
assert(isequal(zeroWait.admittedMessageIds,1:5));
assert(zeroWait.timedOutMask(6));
assert(zeroWait.streamStopTimeMs == 50);
assert(all(zeroWait.suppressedMask(7:12)));
assert(zeroWait.acceptedWorkNotRolledBack);

canceledPending = model(10,20,3,200,true,true);
assert(isequal(canceledPending.admittedMessageIds,1:5));
assert(canceledPending.canceledMask(6));
assert(canceledPending.canceledCount == 1);
assert(canceledPending.suppressedCount == 6);
assert(canceledPending.failedCount == 7);
assert(canceledPending.streamStopTimeMs == 55);
assert(strcmp(canceledPending.streamStopReason, ...
    'pending-cancellation'));
assert(all(canceledPending.suppressedMask(7:12)));
assert(canceledPending.completionTimeOfBatchMs == 100);
assert(canceledPending.acceptedPrefixPreserved);
assert(canceledPending.cancellationRequestModeled);
assert(canceledPending.cancellationRemovesOnlyPendingDemand);
assert(~canceledPending.cancellationCouldNotUndoAdmission);
assert(~canceledPending.actualAsynchronousCancellationPerformed);
assert(~canceledPending.rollbackModeled);
assert(~canceledPending.actualRollbackPerformed);
assert(canceledPending.acceptedWorkNotRolledBack);
assert(canceledPending.laterDemandSuppressedToPreservePrefix);
assert(strcmp(canceledPending.outcome,'backpressure-cancellation'));

cancellationTooLate = model(20,20,1,200,true,true);
assert(cancellationTooLate.losslessCompletion);
assert(cancellationTooLate.admittedMask(6));
assert(cancellationTooLate.canceledCount == 0);
assert(cancellationTooLate.cancellationCouldNotUndoAdmission);
assert(~cancellationTooLate.streamStopped);

% With these inputs, message 6's slot opens exactly at its R_6 + 5 ms
% cancellation instant. Readiness wins that tie, so cancellation cannot
% truncate a message that is admissible at the decision instant.
cancellationAtAdmissionTie = model(5,10,3,200,true,true);
tieWithoutCancellation = model(5,10,3,200,true,false);
assert(cancellationAtAdmissionTie.demandReadyTimeMs(6) == 25);
assert(cancellationAtAdmissionTie.admissionTimeMs(6) == 30);
assert(cancellationAtAdmissionTie.admissionTimeMs(6) == ...
    cancellationAtAdmissionTie.demandReadyTimeMs(6) + 5);
assert(cancellationAtAdmissionTie.admittedMask(6));
assert(~cancellationAtAdmissionTie.canceledMask(6));
assert(cancellationAtAdmissionTie.canceledCount == 0);
assert(cancellationAtAdmissionTie.losslessCompletion);
assert(~cancellationAtAdmissionTie.streamStopped);
assert(cancellationAtAdmissionTie.cancellationRequestModeled);
assert(cancellationAtAdmissionTie.cancellationCouldNotUndoAdmission);
assert(isequal(cancellationAtAdmissionTie.admissionTimeMs, ...
    tieWithoutCancellation.admissionTimeMs));
assert(isequal(cancellationAtAdmissionTie.completionTimeMs, ...
    tieWithoutCancellation.completionTimeMs));

recoveryAfterTimeout = model(10,20,3,200,true,false);
recoveryAfterCancellation = model(10,20,3,200,true,false);
recoveryAfterBrokenPolicy = model(10,20,3,200,true,false);
assert(isequaln(recoveryAfterTimeout,baseline));
assert(isequaln(recoveryAfterCancellation,baseline));
assert(isequaln(recoveryAfterBrokenPolicy,baseline));
assert(~baseline.recoveryModeled);
assert(baseline.freshEvaluationRequiredForRecoveryTarget);

%% Explicit abstraction and evidence boundaries
assert(baseline.capacityIncludesMessageInService);
assert(baseline.completionCreditBeforeCoincidentAdmission);
assert(baseline.pendingDemandRemainsUpstream);
assert(baseline.feedbackDelayMs == 0);
assert(baseline.instantaneousReadinessFeedbackAssumed);
assert(~baseline.feedbackOvershootModeled);
assert(baseline.fifoConsumerModeled);
assert(baseline.singleProducerOrderAssumed);
assert(~baseline.consumerCreatesCapacity);
assert(~baseline.backpressureCreatesServiceCapacity);
assert(baseline.timeoutModeled);
assert(baseline.timeoutIsArithmeticClassification);
assert(~baseline.actualWallClockWaitPerformed);
assert(~baseline.actualAsynchronousCancellationPerformed);
assert(~baseline.rollbackModeled);
assert(~baseline.actualRollbackPerformed);
assert(baseline.acceptedWorkNotRolledBack);
assert(~baseline.recoveryModeled);
assert(~baseline.retryModeled);
assert(~baseline.retransmissionModeled);
assert(~baseline.creditProtocolModeled);
assert(~baseline.transportProtocolModeled);
assert(~baseline.networkIoPerformed);
assert(~baseline.storageIoPerformed);
assert(~baseline.backgroundWorkStarted);
assert(~baseline.physicalHardwareUsed);
assert(baseline.calculationBounded);
assert(baseline.maxReceiverCapacityMessages == 12);
assert(baseline.maxObservationEventCount == 36);
assert(baseline.maxAdmissionComparisonCount == 638);
assert(baseline.admissionComparisonCount <= ...
    baseline.maxAdmissionComparisonCount);
assert(baseline.observationEventCount <= baseline.maxObservationEventCount);
assert(baseline.observationEndTimeMs <= baseline.maxDerivedTimeMs);

%% Stable malformed-input failures and stateless recovery
assertThrows(@() model([],20,3,200,true,false), ...
    'P11:InvalidProducerInterval');
assertThrows(@() model('10',20,3,200,true,false), ...
    'P11:InvalidProducerInterval');
assertThrows(@() model([10 10],20,3,200,true,false), ...
    'P11:InvalidProducerInterval');
assertThrows(@() model(10 + 1i,20,3,200,true,false), ...
    'P11:InvalidProducerInterval');
assertThrows(@() model(nan,20,3,200,true,false), ...
    'P11:InvalidProducerInterval');
assertThrows(@() model(inf,20,3,200,true,false), ...
    'P11:InvalidProducerInterval');
assertThrows(@() model(0,20,3,200,true,false), ...
    'P11:InvalidProducerInterval');
assertThrows(@() model(1001,20,3,200,true,false), ...
    'P11:InvalidProducerInterval');

assertThrows(@() model(10,[],3,200,true,false), ...
    'P11:InvalidServiceTime');
assertThrows(@() model(10,'20',3,200,true,false), ...
    'P11:InvalidServiceTime');
assertThrows(@() model(10,[20 20],3,200,true,false), ...
    'P11:InvalidServiceTime');
assertThrows(@() model(10,20 + 1i,3,200,true,false), ...
    'P11:InvalidServiceTime');
assertThrows(@() model(10,nan,3,200,true,false), ...
    'P11:InvalidServiceTime');
assertThrows(@() model(10,inf,3,200,true,false), ...
    'P11:InvalidServiceTime');
assertThrows(@() model(10,0,3,200,true,false), ...
    'P11:InvalidServiceTime');
assertThrows(@() model(10,1001,3,200,true,false), ...
    'P11:InvalidServiceTime');

assertThrows(@() model(10,20,[],200,true,false), ...
    'P11:InvalidCapacity');
assertThrows(@() model(10,20,'3',200,true,false), ...
    'P11:InvalidCapacity');
assertThrows(@() model(10,20,[3 3],200,true,false), ...
    'P11:InvalidCapacity');
assertThrows(@() model(10,20,3 + 1i,200,true,false), ...
    'P11:InvalidCapacity');
assertThrows(@() model(10,20,nan,200,true,false), ...
    'P11:InvalidCapacity');
assertThrows(@() model(10,20,inf,200,true,false), ...
    'P11:InvalidCapacity');
assertThrows(@() model(10,20,-1,200,true,false), ...
    'P11:InvalidCapacity');
assertThrows(@() model(10,20,1.5,200,true,false), ...
    'P11:InvalidCapacity');
assertThrows(@() model(10,20,13,200,true,false), ...
    'P11:InvalidCapacity');

assertThrows(@() model(10,20,3,[],true,false), ...
    'P11:InvalidMaxWait');
assertThrows(@() model(10,20,3,'200',true,false), ...
    'P11:InvalidMaxWait');
assertThrows(@() model(10,20,3,[200 200],true,false), ...
    'P11:InvalidMaxWait');
assertThrows(@() model(10,20,3,200 + 1i,true,false), ...
    'P11:InvalidMaxWait');
assertThrows(@() model(10,20,3,nan,true,false), ...
    'P11:InvalidMaxWait');
assertThrows(@() model(10,20,3,inf,true,false), ...
    'P11:InvalidMaxWait');
assertThrows(@() model(10,20,3,-1,true,false), ...
    'P11:InvalidMaxWait');
assertThrows(@() model(10,20,3,1e6 + 1,true,false), ...
    'P11:InvalidMaxWait');

assertThrows(@() model(10,20,3,200,[],false), ...
    'P11:InvalidBackpressurePolicy');
assertThrows(@() model(10,20,3,200,'true',false), ...
    'P11:InvalidBackpressurePolicy');
assertThrows(@() model(10,20,3,200,[1 1],false), ...
    'P11:InvalidBackpressurePolicy');
assertThrows(@() model(10,20,3,200,1 + 1i,false), ...
    'P11:InvalidBackpressurePolicy');
assertThrows(@() model(10,20,3,200,nan,false), ...
    'P11:InvalidBackpressurePolicy');
assertThrows(@() model(10,20,3,200,2,false), ...
    'P11:InvalidBackpressurePolicy');

assertThrows(@() model(10,20,3,200,true,[]), ...
    'P11:InvalidCancellationPolicy');
assertThrows(@() model(10,20,3,200,true,'false'), ...
    'P11:InvalidCancellationPolicy');
assertThrows(@() model(10,20,3,200,true,[0 0]), ...
    'P11:InvalidCancellationPolicy');
assertThrows(@() model(10,20,3,200,true,1 + 1i), ...
    'P11:InvalidCancellationPolicy');
assertThrows(@() model(10,20,3,200,true,nan), ...
    'P11:InvalidCancellationPolicy');
assertThrows(@() model(10,20,3,200,true,-1), ...
    'P11:InvalidCancellationPolicy');

recoveredAfterMalformed = model(10,20,3,200,true,false);
assert(isequaln(recoveredAfterMalformed,baseline));

fprintf(['P11 checks passed: completion-credit backpressure, two sweeps, ' ...
    'broken readiness, timeout/cancellation, recovery targets, and bounds.\n']);
end

function assertThrows(action,expectedIdentifier)
%ASSERTTHROWS Check one stable malformed-input identifier.
caught = false;
try
    action();
catch caughtError
    caught = true;
    assert(strcmp(caughtError.identifier,expectedIdentifier), ...
        'Expected %s but received %s.', ...
        expectedIdentifier,caughtError.identifier);
end
assert(caught,'Expected error %s was not thrown.',expectedIdentifier);
end
