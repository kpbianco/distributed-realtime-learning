function run_checks
%RUN_CHECKS Independent deterministic checks for P09.

baseline = model();
assert(baseline.propagationDelayScale == 1);
assert(baseline.requiredAckCount == 4);
assert(baseline.readAfterResponseMs == 0);
assert(baseline.slowReplicaAvailable);
assert(baseline.ackTimeoutMs == 160);
assert(isequal(baseline.replicaIndex,1:4));
assert(isequal(baseline.replicaAvailable,[true true true true]));
assert(isequal(baseline.basePropagationDelayMs,[0 10 30 70]));
assert(isequal(baseline.applyCostMs,[0 5 5 5]));
assert(isequal(baseline.ackReturnDelayMs,[0 0 0 0]));
assert(isequal(baseline.nominalApplyTimeMs,[0 15 35 75]));
assert(isequal(baseline.effectiveApplyTimeMs,[0 15 35 75]));
assert(isequal(baseline.ackObservationTimeMs,[0 15 35 75]));
assert(isequal(baseline.orderedAckTimeMs,[0 15 35 75]));
assert(baseline.requiredAckArrivalTimeMs == 75);
assert(baseline.ackThresholdReachable && baseline.writeAcknowledged);
assert(~baseline.ackTimedOut && baseline.clientResponseTimeMs == 75);
assert(baseline.acknowledgmentLatencyMs == 75);
assert(isnan(baseline.timeoutDecisionLatencyMs));
assert(isequal(baseline.replicaCurrentAtResponse, ...
    [true true true true]));
assert(isequal(baseline.replicaVersionAtResponse,[1 1 1 1]));
assert(isequal(baseline.replicaValueAtResponsePercent,[65 65 65 65]));
assert(baseline.currentReplicaCountAtResponse == 4);
assert(baseline.allReplicasCurrentAtResponse);
assert(baseline.allAvailableReplicasCurrentAtResponse);
assert(~baseline.partialApplyAtResponse);
assert(~baseline.writeMayHaveAppliedDespiteTimeout);
assert(baseline.readTimeMs == 75 && baseline.readSucceeded);
assert(baseline.readVersion == 1 && baseline.readValuePercent == 65);
assert(~baseline.staleReadObserved && baseline.readVersionLag == 0);
assert(baseline.readYourWriteApplicable && ...
    baseline.readYourWriteSatisfied);
assert(baseline.convergenceReached && baseline.convergenceTimeMs == 75);
assert(baseline.availableConvergenceTimeMs == 75);
assert(baseline.allReplicaLagExposureReplicaMs == 125);
assert(baseline.onlineReplicaLagExposureReplicaMs == 125);
assert(strcmp(baseline.outcome,'acknowledged-current-read'));

repeated = model();
assert(isequal(repeated.nominalApplyTimeMs, ...
    baseline.nominalApplyTimeMs));
assert(isequal(repeated.replicaVersionAtRead, ...
    baseline.replicaVersionAtRead));
assert(strcmp(repeated.outcome,baseline.outcome));

typed = model(single(1),uint8(4),single(0),uint8(1),uint16(160));
assert(isa(typed.propagationDelayScale,'double'));
assert(isa(typed.requiredAckCount,'double'));
assert(isa(typed.readAfterResponseMs,'double'));
assert(islogical(typed.slowReplicaAvailable));
assert(isa(typed.ackTimeoutMs,'double'));
assert(isequal(typed.nominalApplyTimeMs,baseline.nominalApplyTimeMs));
assert(typed.acknowledgmentLatencyMs == ...
    baseline.acknowledgmentLatencyMs);

fractional = model(0.5,2,2.5,true,40.5);
assert(isequal(fractional.nominalApplyTimeMs,[0 10 20 40]));
assert(fractional.acknowledgmentLatencyMs == 10);
assert(fractional.readTimeMs == 12.5);
assert(fractional.readVersion == 0 && fractional.staleReadObserved);

propagationDelayScales = [0.5 1 2];
expectedApplyTimeMs = [0 10 20 40;0 15 35 75;0 25 65 145];
expectedConvergenceTimeMs = [40 75 145];
expectedLagExposureReplicaMs = [70 125 235];
for caseIndex = 1:numel(propagationDelayScales)
    scale = propagationDelayScales(caseIndex);
    current = model(scale,4,0,true,160);
    independentlyCalculatedApplyTimeMs = ...
        scale * [0 10 30 70] + [0 5 5 5];
    assert(isequal(current.nominalApplyTimeMs, ...
        independentlyCalculatedApplyTimeMs));
    assert(isequal(current.nominalApplyTimeMs, ...
        expectedApplyTimeMs(caseIndex,:)));
    assert(current.acknowledgmentLatencyMs == ...
        expectedConvergenceTimeMs(caseIndex));
    assert(current.convergenceTimeMs == ...
        expectedConvergenceTimeMs(caseIndex));
    assert(current.allReplicaLagExposureReplicaMs == ...
        expectedLagExposureReplicaMs(caseIndex));
end

requiredAckCounts = [1 2 4];
expectedAckLatencyMs = [0 15 75];
expectedCurrentReplicaCount = [1 2 4];
expectedSlowReadVersion = [0 0 1];
for caseIndex = 1:numel(requiredAckCounts)
    current = model(1,requiredAckCounts(caseIndex),0,true,160);
    independentlyOrderedApplyTimeMs = sort([0 15 35 75]);
    assert(current.acknowledgmentLatencyMs == ...
        independentlyOrderedApplyTimeMs(requiredAckCounts(caseIndex)));
    assert(current.acknowledgmentLatencyMs == ...
        expectedAckLatencyMs(caseIndex));
    assert(current.currentReplicaCountAtResponse == ...
        expectedCurrentReplicaCount(caseIndex));
    assert(current.readVersion == expectedSlowReadVersion(caseIndex));
end

zeroPropagation = model(0,4,0,true,160);
assert(isequal(zeroPropagation.nominalApplyTimeMs,[0 5 5 5]));
assert(zeroPropagation.acknowledgmentLatencyMs == 5);
assert(zeroPropagation.convergenceTimeMs == 5);
assert(zeroPropagation.allReplicaLagExposureReplicaMs == 15);

zeroTimeoutPrimaryAck = model(1,1,0,true,0);
assert(zeroTimeoutPrimaryAck.writeAcknowledged);
assert(zeroTimeoutPrimaryAck.clientResponseTimeMs == 0);
assert(zeroTimeoutPrimaryAck.currentReplicaCountAtResponse == 1);

zeroTimeoutTwoAcks = model(1,2,0,true,0);
assert(zeroTimeoutTwoAcks.ackTimedOut);
assert(zeroTimeoutTwoAcks.clientResponseTimeMs == 0);
assert(zeroTimeoutTwoAcks.currentReplicaCountAtResponse == 1);
assert(zeroTimeoutTwoAcks.writeMayHaveAppliedDespiteTimeout);

exactAckTimeout = model(1,4,0,true,75);
justBeforeAckTimeout = model(1,4,0,true,75 - 1e-12);
assert(exactAckTimeout.writeAcknowledged);
assert(exactAckTimeout.acknowledgmentLatencyMs == 75);
assert(justBeforeAckTimeout.ackTimedOut);
assert(justBeforeAckTimeout.currentReplicaCountAtResponse == 3);
assert(justBeforeAckTimeout.partialApplyAtResponse);

broken = model(1,1,0,true,160);
assert(broken.writeAcknowledged && broken.clientResponseTimeMs == 0);
assert(isequal(broken.replicaVersionAtResponse,[1 0 0 0]));
assert(broken.readSucceeded && broken.readVersion == 0);
assert(broken.readValuePercent == 40 && broken.staleReadObserved);
assert(broken.readVersionLag == 1);
assert(broken.readYourWriteApplicable && ...
    ~broken.readYourWriteSatisfied);
assert(strcmp(broken.outcome,'acknowledged-stale-read'));

justBeforeReadBoundary = model(1,1,75 - 1e-12,true,160);
exactReadBoundary = model(1,1,75,true,160);
assert(justBeforeReadBoundary.readVersion == 0);
assert(justBeforeReadBoundary.staleReadObserved);
assert(exactReadBoundary.readVersion == 1);
assert(~exactReadBoundary.staleReadObserved);
assert(exactReadBoundary.readYourWriteSatisfied);

coherentAllAck = model(1,4,0,true,160);
assert(coherentAllAck.writeAcknowledged);
assert(coherentAllAck.allReplicasCurrentAtResponse);
assert(coherentAllAck.readYourWriteSatisfied);

onlineTimedOutStaleRead = model(1,4,0,true,74);
assert(onlineTimedOutStaleRead.ackTimedOut);
assert(onlineTimedOutStaleRead.clientResponseTimeMs == 74);
assert(onlineTimedOutStaleRead.currentReplicaCountAtResponse == 3);
assert(onlineTimedOutStaleRead.writeMayHaveAppliedDespiteTimeout);
assert(onlineTimedOutStaleRead.readTimeMs == 74);
assert(onlineTimedOutStaleRead.readSucceeded);
assert(~onlineTimedOutStaleRead.replicaCurrentAtRead(4));
assert(onlineTimedOutStaleRead.readVersion == 0);
assert(onlineTimedOutStaleRead.staleReadObserved);
assert(onlineTimedOutStaleRead.readVersionLag == 1);
assert(~onlineTimedOutStaleRead.readYourWriteApplicable);
assert(~onlineTimedOutStaleRead.readYourWriteSatisfied);
assert(strcmp(onlineTimedOutStaleRead.outcome,'timeout-stale-read'));

onlineLateAck = model(1,4,1,true,74);
assert(onlineLateAck.ackTimedOut);
assert(onlineLateAck.currentReplicaCountAtResponse == 3);
assert(onlineLateAck.writeMayHaveAppliedDespiteTimeout);
assert(~onlineLateAck.replicaCurrentAtResponse(4));
assert(onlineLateAck.readTimeMs == 75);
assert(onlineLateAck.replicaCurrentAtRead(4));
assert(onlineLateAck.readVersion == 1);
assert(~onlineLateAck.cancellationModeled);
assert(strcmp(onlineLateAck.outcome,'timeout-current-read'));

offlineAllAck = model(1,4,0,false,100);
assert(isequal(offlineAllAck.replicaAvailable, ...
    [true true true false]));
assert(isequal(offlineAllAck.nominalApplyTimeMs,[0 15 35 75]));
assert(isinf(offlineAllAck.effectiveApplyTimeMs(4)));
assert(isinf(offlineAllAck.requiredAckArrivalTimeMs));
assert(~offlineAllAck.ackThresholdReachable);
assert(offlineAllAck.ackTimedOut && ...
    ~offlineAllAck.writeAcknowledged);
assert(offlineAllAck.clientResponseTimeMs == 100);
assert(isnan(offlineAllAck.acknowledgmentLatencyMs));
assert(offlineAllAck.timeoutDecisionLatencyMs == 100);
assert(isequal(offlineAllAck.replicaCurrentAtResponse, ...
    [true true true false]));
assert(isequal(offlineAllAck.replicaVersionAtResponse,[1 1 1 0]));
assert(offlineAllAck.currentReplicaCountAtResponse == 3);
assert(offlineAllAck.allAvailableReplicasCurrentAtResponse);
assert(~offlineAllAck.allReplicasCurrentAtResponse);
assert(offlineAllAck.partialApplyAtResponse);
assert(offlineAllAck.writeMayHaveAppliedDespiteTimeout);
assert(~offlineAllAck.readSucceeded);
assert(isnan(offlineAllAck.readVersion));
assert(~offlineAllAck.staleReadObserved);
assert(~offlineAllAck.readYourWriteApplicable);
assert(~offlineAllAck.convergenceReached);
assert(isnan(offlineAllAck.convergenceTimeMs));
assert(offlineAllAck.availableConvergenceTimeMs == 35);
assert(isnan(offlineAllAck.allReplicaLagExposureReplicaMs));
assert(offlineAllAck.onlineReplicaLagExposureReplicaMs == 50);
assert(offlineAllAck.replicasRequiredButUnavailable == 1);
assert(strcmp(offlineAllAck.outcome,'timeout-read-unavailable'));
assert(~offlineAllAck.rollbackModeled);
assert(~offlineAllAck.actualRollbackPerformed);
assert(offlineAllAck.partialApplyIsNotRolledBack);

offlineThreeAcks = model(1,3,0,false,100);
assert(offlineThreeAcks.writeAcknowledged);
assert(offlineThreeAcks.acknowledgmentLatencyMs == 35);
assert(offlineThreeAcks.currentReplicaCountAtResponse == 3);
assert(offlineThreeAcks.allAvailableReplicasCurrentAtResponse);
assert(~offlineThreeAcks.readSucceeded);
assert(strcmp(offlineThreeAcks.outcome, ...
    'acknowledged-read-unavailable'));

recoveryTarget = model(1,4,0,true,160);
assert(recoveryTarget.writeAcknowledged);
assert(recoveryTarget.convergenceReached);
assert(recoveryTarget.readVersion == 1);
assert(isequal(recoveryTarget.nominalApplyTimeMs, ...
    baseline.nominalApplyTimeMs));

bounded = model(20,4,1e6,true,1e6);
assert(isequal(bounded.nominalApplyTimeMs,[0 205 605 1405]));
assert(bounded.acknowledgmentLatencyMs == 1405);
assert(bounded.readTimeMs == 1001405);
assert(bounded.readVersion == 1);
assert(bounded.replicaCount == 4 && bounded.updateCount == 1);
assert(numel(bounded.nominalApplyTimeMs) == 4);
assert(numel(bounded.replicaVersionAtResponse) == 4);
assert(all(isfinite(bounded.nominalApplyTimeMs)));
assert(isfinite(bounded.readTimeMs));
assert(bounded.readTimeMs <= bounded.maxDerivedTimeMs);
assert(bounded.calculationBounded);

assert(baseline.singleWriterAssumed && baseline.replicationModeled);
assert(baseline.acknowledgmentThresholdModeled);
assert(baseline.ackReturnDelayAssumedZero);
assert(~baseline.ackReturnTransportModeled);
assert(~baseline.ackLossModeled);
assert(baseline.acknowledgmentObservationUsesTeachingOracle);
assert(baseline.timeoutModeled && ...
    baseline.timeoutIsArithmeticClassification);
assert(~baseline.actualWaitPerformed);
assert(~baseline.cancellationModeled);
assert(~baseline.actualCancellationPerformed);
assert(~baseline.rollbackModeled && ...
    ~baseline.actualRollbackPerformed);
assert(baseline.recoveryRequiresReplicaCatchUp);
assert(~baseline.writeOrderingModeled);
assert(~baseline.concurrentWritersModeled);
assert(~baseline.conflictResolutionModeled);
assert(~baseline.consensusModeled && ...
    ~baseline.quorumConsensusModeled);
assert(~baseline.failureDetectorModeled);
assert(~baseline.retryProtocolModeled && ...
    ~baseline.deduplicationModeled);
assert(~baseline.networkIoPerformed && ~baseline.storageIoPerformed);
assert(~baseline.backgroundWorkStarted && ~baseline.physicalHardwareUsed);
assert(strcmp(baseline.namedBrokenAssumption, ...
    'acknowledgment threshold is not universal visibility'));

assertThrows(@() model([],4,0,true,160), ...
    'P09:InvalidPropagationDelayScale');
assertThrows(@() model('slow',4,0,true,160), ...
    'P09:InvalidPropagationDelayScale');
assertThrows(@() model([1 2],4,0,true,160), ...
    'P09:InvalidPropagationDelayScale');
assertThrows(@() model(1 + 1i,4,0,true,160), ...
    'P09:InvalidPropagationDelayScale');
assertThrows(@() model(nan,4,0,true,160), ...
    'P09:InvalidPropagationDelayScale');
assertThrows(@() model(inf,4,0,true,160), ...
    'P09:InvalidPropagationDelayScale');
assertThrows(@() model(-eps,4,0,true,160), ...
    'P09:InvalidPropagationDelayScale');
assertThrows(@() model(20 + eps(20),4,0,true,160), ...
    'P09:InvalidPropagationDelayScale');

assertThrows(@() model(1,[],0,true,160), ...
    'P09:InvalidRequiredAckCount');
assertThrows(@() model(1,'four',0,true,160), ...
    'P09:InvalidRequiredAckCount');
assertThrows(@() model(1,[1 2],0,true,160), ...
    'P09:InvalidRequiredAckCount');
assertThrows(@() model(1,2 + 1i,0,true,160), ...
    'P09:InvalidRequiredAckCount');
assertThrows(@() model(1,nan,0,true,160), ...
    'P09:InvalidRequiredAckCount');
assertThrows(@() model(1,inf,0,true,160), ...
    'P09:InvalidRequiredAckCount');
assertThrows(@() model(1,0,0,true,160), ...
    'P09:InvalidRequiredAckCount');
assertThrows(@() model(1,5,0,true,160), ...
    'P09:InvalidRequiredAckCount');
assertThrows(@() model(1,1.5,0,true,160), ...
    'P09:InvalidRequiredAckCount');

assertThrows(@() model(1,4,[],true,160), ...
    'P09:InvalidReadDelay');
assertThrows(@() model(1,4,'now',true,160), ...
    'P09:InvalidReadDelay');
assertThrows(@() model(1,4,[0 1],true,160), ...
    'P09:InvalidReadDelay');
assertThrows(@() model(1,4,1i,true,160), ...
    'P09:InvalidReadDelay');
assertThrows(@() model(1,4,nan,true,160), ...
    'P09:InvalidReadDelay');
assertThrows(@() model(1,4,inf,true,160), ...
    'P09:InvalidReadDelay');
assertThrows(@() model(1,4,-eps,true,160), ...
    'P09:InvalidReadDelay');
assertThrows(@() model(1,4,1e6 + eps(1e6),true,160), ...
    'P09:InvalidReadDelay');

assertThrows(@() model(1,4,0,[],160), ...
    'P09:InvalidReplicaAvailability');
assertThrows(@() model(1,4,0,'online',160), ...
    'P09:InvalidReplicaAvailability');
assertThrows(@() model(1,4,0,[true false],160), ...
    'P09:InvalidReplicaAvailability');
assertThrows(@() model(1,4,0,1i,160), ...
    'P09:InvalidReplicaAvailability');
assertThrows(@() model(1,4,0,nan,160), ...
    'P09:InvalidReplicaAvailability');
assertThrows(@() model(1,4,0,inf,160), ...
    'P09:InvalidReplicaAvailability');
assertThrows(@() model(1,4,0,-1,160), ...
    'P09:InvalidReplicaAvailability');
assertThrows(@() model(1,4,0,2,160), ...
    'P09:InvalidReplicaAvailability');
assertThrows(@() model(1,4,0,0.5,160), ...
    'P09:InvalidReplicaAvailability');

assertThrows(@() model(1,4,0,true,[]), ...
    'P09:InvalidAckTimeout');
assertThrows(@() model(1,4,0,true,'later'), ...
    'P09:InvalidAckTimeout');
assertThrows(@() model(1,4,0,true,[1 2]), ...
    'P09:InvalidAckTimeout');
assertThrows(@() model(1,4,0,true,1i), ...
    'P09:InvalidAckTimeout');
assertThrows(@() model(1,4,0,true,nan), ...
    'P09:InvalidAckTimeout');
assertThrows(@() model(1,4,0,true,inf), ...
    'P09:InvalidAckTimeout');
assertThrows(@() model(1,4,0,true,-eps), ...
    'P09:InvalidAckTimeout');
assertThrows(@() model(1,4,0,true,1e6 + eps(1e6)), ...
    'P09:InvalidAckTimeout');

recoveredAfterMalformed = model();
assert(isequal(recoveredAfterMalformed.nominalApplyTimeMs, ...
    baseline.nominalApplyTimeMs));
assert(isequal(recoveredAfterMalformed.replicaVersionAtResponse, ...
    baseline.replicaVersionAtResponse));
assert(recoveredAfterMalformed.readYourWriteSatisfied);

fprintf(['P09 checks passed: baseline, two sweeps, exact limits, stale read, ' ...
    'timeout stale/current continuation, partial apply, recovery target, ' ...
    'malformed inputs, isolation, and bounds.\n']);
end

function assertThrows(functionHandle,expectedIdentifier)
try
    functionHandle();
catch caught
    assert(strcmp(caught.identifier,expectedIdentifier), ...
        'Expected %s but received %s.', ...
        expectedIdentifier,caught.identifier);
    return;
end
error('P09:ExpectedErrorNotThrown', ...
    'Expected error %s was not thrown.',expectedIdentifier);
end
