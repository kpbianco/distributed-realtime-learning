function run_checks
%RUN_CHECKS Independent deterministic checks for P10 message ordering.

baseline = model(1,2,100,true,true);
expectedSequence = 1:6;
expectedSendTimeMs = (expectedSequence - 1) * 10;
expectedBaseDelayMs = [20 5 35 5 25 0];
expectedArrivalTimeMs = expectedSendTimeMs + expectedBaseDelayMs;
expectedEvents = sortrows( ...
    [expectedArrivalTimeMs(:),expectedSequence(:)],[1 2]);
expectedArrivalSequence = expectedEvents(:,2).';
expectedArrivalEventTimeMs = expectedEvents(:,1).';

assert(isequal(baseline.sequence,expectedSequence));
assert(isequal(baseline.sendTimeMs,expectedSendTimeMs));
assert(isequal(baseline.baseNetworkDelayMs,expectedBaseDelayMs));
assert(isequal(baseline.networkDelayMs,expectedBaseDelayMs));
assert(isequal(baseline.arrivalTimeMs,expectedArrivalTimeMs));
assert(isequal(expectedArrivalSequence,[2 1 4 6 3 5]));
assert(isequal(baseline.arrivalSequence,expectedArrivalSequence));
assert(isequal(baseline.arrivalEventTimeMs, ...
    expectedArrivalEventTimeMs));
assert(baseline.arrivalInversionCount == 4);
assert(~baseline.arrivalOrderMatchesSendOrder);
assert(isequal(baseline.deliverySequence,expectedSequence));
assert(isequal(baseline.deliveryEventTimeMs,[20 20 55 55 65 65]));
assert(isequal(baseline.deliveryTimeBySequenceMs, ...
    [20 20 55 55 65 65]));
assert(baseline.deliveryInversionCount == 0);
assert(baseline.deliveredPrefixOrdered);
assert(baseline.completeOrderedDelivery);
assert(baseline.deliveredMessageCount == 6);
assert(baseline.allMessagesDelivered);
assert(baseline.completionTimeMs == 65);
assert(isequal(baseline.holdTimeBySequenceMs,[0 5 0 20 0 15]));
assert(all(baseline.holdTimeBySequenceMs >= 0));
assert(baseline.totalOrderingHoldMessageMs == 40);
assert(abs(baseline.meanOrderingHoldMs - 40/6) < 1e-12);
assert(baseline.maxOrderingHoldMs == 20);
assert(isequal(baseline.bufferOccupancyAfterEvent,[1 0 1 2 1 0]));
assert(baseline.reorderBufferHighWaterCount == 2);
assert(all(baseline.bufferOccupancyAfterEvent <= ...
    baseline.reorderBufferCapacity));
assert(baseline.bufferedAtTerminationCount == 0);
assert(baseline.expectedSequenceAtTermination == 7);
assert(~baseline.gapActiveAtTermination);
assert(~baseline.timedOut && ~baseline.bufferOverflow);
assert(~baseline.streamTerminated);
assert(strcmp(baseline.terminationReason,'complete-ordered'));
assert(baseline.processedEventCount == 6);
assert(baseline.inFlightAtTerminationCount == 0);
assert(baseline.missingMessageCount == 0);
assert(baseline.deliverySuppressedMessageCount == 0);
assert(baseline.undeliveredMessageCount == 0);
assert(~baseline.remainingDeliverySuppressedAfterFailure);
assert(~baseline.partialDelivery);
assert(isequal(baseline.stateVersionTrace,0:6));
assert(baseline.finalStateVersion == 6);
assert(baseline.stateRegressionCount == 0);
assert(baseline.finalStateIsLatest);
assert(all(baseline.deliveryTimeBySequenceMs >= ...
    baseline.arrivalTimeMs));
assert(all(diff(baseline.deliveryTimeBySequenceMs) >= 0));

independentInversionCount = 0;
for leftIndex = 1:numel(expectedArrivalSequence)
    for rightIndex = leftIndex + 1:numel(expectedArrivalSequence)
        independentInversionCount = independentInversionCount + ...
            (expectedArrivalSequence(leftIndex) > ...
            expectedArrivalSequence(rightIndex));
    end
end
assert(independentInversionCount == baseline.arrivalInversionCount);

repeated = model(1,2,100,true,true);
assert(isequaln(repeated,baseline));
typed = model(single(1),uint8(2),single(100),uint8(1),int8(1));
assert(isequal(typed.arrivalSequence,baseline.arrivalSequence));
assert(isequal(typed.deliverySequence,baseline.deliverySequence));
assert(isa(typed.delayScale,'double'));
assert(isa(typed.reorderBufferCapacity,'double'));
assert(isa(typed.gapTimeoutMs,'double'));
assert(islogical(typed.messageThreeAvailable));
assert(islogical(typed.preserveSequenceOrder));

fractional = model(0.5,2,20.5,true,true);
assert(isequal(fractional.arrivalTimeMs, ...
    [10 12.5 37.5 32.5 52.5 50]));
assert(isequal(fractional.arrivalSequence,[1 2 4 3 6 5]));
assert(isequal(fractional.deliverySequence,1:6));
assert(fractional.completeOrderedDelivery);
assert(fractional.totalOrderingHoldMessageMs == 7.5);

explicitTieRule = model(2,6,1e6,true,true);
assert(isequal(explicitTieRule.arrivalTimeMs,[40 20 90 40 90 50]));
assert(isequal(explicitTieRule.arrivalSequence,[2 1 4 6 3 5]));
assert(strcmp(explicitTieRule.arrivalTieBreakRule, ...
    'lower sequence first at equal analytical arrival time'));
assert(explicitTieRule.completeOrderedDelivery);

delayScales = [0 0.5 1 2];
expectedArrivalInversions = [0 2 4 4];
expectedBufferHighWater = [0 1 2 2];
expectedHoldingMessageMs = [0 7.5 40 110];
expectedCompletionMs = [50 52.5 65 90];
for caseIndex = 1:numel(delayScales)
    current = model(delayScales(caseIndex),2,100,true,true);
    independentArrival = expectedSendTimeMs + ...
        delayScales(caseIndex) * expectedBaseDelayMs;
    assert(isequal(current.arrivalTimeMs,independentArrival));
    assert(current.arrivalInversionCount == ...
        expectedArrivalInversions(caseIndex));
    assert(current.reorderBufferHighWaterCount == ...
        expectedBufferHighWater(caseIndex));
    assert(current.totalOrderingHoldMessageMs == ...
        expectedHoldingMessageMs(caseIndex));
    assert(current.completionTimeMs == expectedCompletionMs(caseIndex));
    assert(current.completeOrderedDelivery);
    assert(isequal(current.deliverySequence,expectedSequence));
end

bufferCapacities = [0 1 2];
expectedDeliveredCount = [0 2 6];
expectedCapacityHighWater = [0 1 2];
expectedDecisionTimeMs = [15 50 65];
expectedCapacityComplete = [false false true];
for caseIndex = 1:numel(bufferCapacities)
    current = model(1,bufferCapacities(caseIndex),100,true,true);
    assert(current.deliveredMessageCount == ...
        expectedDeliveredCount(caseIndex));
    assert(current.reorderBufferHighWaterCount == ...
        expectedCapacityHighWater(caseIndex));
    assert(current.completeOrderedDelivery == ...
        expectedCapacityComplete(caseIndex));
    if current.completeOrderedDelivery
        decisionTimeMs = current.completionTimeMs;
    else
        decisionTimeMs = current.failureTimeMs;
    end
    assert(decisionTimeMs == expectedDecisionTimeMs(caseIndex));
    assert(current.reorderBufferHighWaterCount <= ...
        current.reorderBufferCapacity);
    assert(current.deliveredPrefixOrdered);
end

zeroDelay = model(0,0,0,true,true);
assert(isequal(zeroDelay.arrivalTimeMs,zeroDelay.sendTimeMs));
assert(isequal(zeroDelay.arrivalSequence,1:6));
assert(isequal(zeroDelay.deliverySequence,1:6));
assert(zeroDelay.arrivalInversionCount == 0);
assert(zeroDelay.reorderBufferHighWaterCount == 0);
assert(zeroDelay.totalOrderingHoldMessageMs == 0);
assert(zeroDelay.completeOrderedDelivery);
assert(zeroDelay.completionTimeMs == 50);

naiveZeroDelay = model(0,0,0,true,false);
assert(isequal(naiveZeroDelay.deliverySequence,1:6));
assert(naiveZeroDelay.completeOrderedDelivery);
assert(~naiveZeroDelay.reorderBufferModeled);
assert(strcmp(naiveZeroDelay.terminationReason, ...
    'arrival-order-delivery'));

capacityAboveNeed = model(1,6,100,true,true);
assert(isequal(capacityAboveNeed.deliverySequence, ...
    baseline.deliverySequence));
assert(isequal(capacityAboveNeed.deliveryTimeBySequenceMs, ...
    baseline.deliveryTimeBySequenceMs));
assert(capacityAboveNeed.reorderBufferHighWaterCount == 2);

zeroCapacity = model(1,0,100,true,true);
assert(zeroCapacity.bufferOverflow);
assert(zeroCapacity.failureTimeMs == 15);
assert(zeroCapacity.rejectedSequence == 2);
assert(zeroCapacity.deliveredMessageCount == 0);
assert(isempty(zeroCapacity.deliverySequence));
assert(zeroCapacity.inFlightAtTerminationCount == 5);
assert(zeroCapacity.deliverySuppressedMessageCount == 6);
assert(zeroCapacity.undeliveredMessageCount == 6);
assert(strcmp(zeroCapacity.terminationReason,'buffer-overflow'));

oneSlotOverflow = model(1,1,100,true,true);
assert(oneSlotOverflow.bufferOverflow);
assert(oneSlotOverflow.failureTimeMs == 50);
assert(oneSlotOverflow.rejectedSequence == 6);
assert(isequal(oneSlotOverflow.deliverySequence,[1 2]));
assert(oneSlotOverflow.deliveredPrefixOrdered);
assert(oneSlotOverflow.deliveredMessageCount == 2);
assert(oneSlotOverflow.bufferedAtTerminationCount == 1);
assert(oneSlotOverflow.inFlightAtTerminationCount == 2);
assert(oneSlotOverflow.deliverySuppressedMessageCount == 4);
assert(oneSlotOverflow.partialDelivery);
assert(oneSlotOverflow.remainingDeliverySuppressedAfterFailure);
assert(oneSlotOverflow.finalStateVersion == 2);

exactGapBoundary = model(1,2,20,true,true);
justBeforeGapBoundary = model(1,2,20 - 1e-12,true,true);
assert(exactGapBoundary.completeOrderedDelivery);
assert(~exactGapBoundary.timedOut);
assert(isequal(exactGapBoundary.deliverySequence,1:6));
assert(justBeforeGapBoundary.timedOut);
assert(justBeforeGapBoundary.failureTimeMs == ...
    35 + (20 - 1e-12));
assert(justBeforeGapBoundary.failureTimeMs < 55);
assert(justBeforeGapBoundary.timeoutExpectedSequence == 3);
assert(isequal(justBeforeGapBoundary.deliverySequence,[1 2]));
assert(justBeforeGapBoundary.bufferedAtTerminationCount == 2);
assert(justBeforeGapBoundary.inFlightAtTerminationCount == 2);
assert(strcmp(justBeforeGapBoundary.terminationReason,'gap-timeout'));

zeroGapTimeout = model(1,2,0,true,true);
assert(zeroGapTimeout.timedOut);
assert(zeroGapTimeout.failureTimeMs == 15);
assert(zeroGapTimeout.timeoutExpectedSequence == 1);
assert(zeroGapTimeout.deliveredMessageCount == 0);
assert(zeroGapTimeout.bufferedAtTerminationCount == 1);
assert(zeroGapTimeout.deliveredPrefixOrdered);

shortGapTimeout = model(1,2,5,true,true);
assert(shortGapTimeout.timedOut);
assert(shortGapTimeout.failureTimeMs == 40);
assert(shortGapTimeout.timeoutExpectedSequence == 3);
assert(isequal(shortGapTimeout.deliverySequence,[1 2]));

missingMessage = model(1,2,20,false,true);
assert(isequal(missingMessage.receivedMask, ...
    [true true false true true true]));
assert(isequal(missingMessage.receivedSequenceInSendOrder,[1 2 4 5 6]));
assert(isequal(missingMessage.arrivalSequence,[2 1 4 6 5]));
assert(missingMessage.receivedMessageCount == 5);
assert(missingMessage.missingMessageCount == 1);
assert(missingMessage.timedOut && ~missingMessage.bufferOverflow);
assert(missingMessage.failureTimeMs == 55);
assert(missingMessage.timeoutExpectedSequence == 3);
assert(isequal(missingMessage.deliverySequence,[1 2]));
assert(missingMessage.deliveredMessageCount == 2);
assert(missingMessage.deliveredPrefixOrdered);
assert(~missingMessage.completeOrderedDelivery);
assert(missingMessage.bufferedAtTerminationCount == 2);
assert(missingMessage.inFlightAtTerminationCount == 1);
assert(missingMessage.deliverySuppressedMessageCount == 3);
assert(missingMessage.undeliveredMessageCount == 4);
assert(missingMessage.remainingDeliverySuppressedAfterFailure);
assert(missingMessage.partialDelivery);
assert(missingMessage.finalStateVersion == 2);
assert(missingMessage.stateRegressionCount == 0);
assert(~missingMessage.finalStateIsLatest);
assert(~missingMessage.actualWaitPerformed);
assert(missingMessage.deliveryStopPolicyModeled);
assert(~missingMessage.actualAsynchronousCancellationPerformed);
assert(~missingMessage.rollbackModeled);
assert(~missingMessage.actualRollbackPerformed);
assert(missingMessage.deliveredPrefixNotRolledBack);
assert(~missingMessage.recoveryModeled);
assert(missingMessage.recoveryRequiresReplayOrReevaluation);

broken = model(1,2,100,true,false);
assert(isequal(broken.deliverySequence,[2 1 4 6 3 5]));
assert(isequal(broken.deliveryEventTimeMs,[15 20 35 50 55 65]));
assert(isequal(broken.deliveryTimeBySequenceMs, ...
    broken.arrivalTimeMs));
assert(broken.deliveryInversionCount == 4);
assert(~broken.deliveredPrefixOrdered);
assert(~broken.completeOrderedDelivery);
assert(broken.allMessagesDelivered);
assert(broken.completionTimeMs == 65);
assert(all(broken.holdTimeBySequenceMs == 0));
assert(broken.totalOrderingHoldMessageMs == 0);
assert(broken.reorderBufferHighWaterCount == 0);
assert(all(broken.bufferOccupancyAfterEvent == 0));
assert(isequal(broken.stateVersionTrace,[0 2 1 4 6 3 5]));
assert(broken.stateRegressionCount == 2);
assert(broken.finalStateVersion == 5);
assert(~broken.finalStateIsLatest);
assert(~broken.streamTerminated);
assert(strcmp(broken.terminationReason,'arrival-order-delivery'));
assert(~broken.reorderBufferModeled);
assert(~broken.bufferCapacityApplicable);
assert(~broken.gapTimeoutApplicable);

brokenMissing = model(1,2,20,false,false);
assert(isequal(brokenMissing.deliverySequence,[2 1 4 6 5]));
assert(brokenMissing.deliveredMessageCount == 5);
assert(~brokenMissing.allMessagesDelivered);
assert(~brokenMissing.timedOut && ~brokenMissing.bufferOverflow);
assert(~brokenMissing.streamTerminated);
assert(brokenMissing.processedEventCount == 5);
assert(brokenMissing.inFlightAtTerminationCount == 0);
assert(brokenMissing.missingMessageCount == 1);
assert(brokenMissing.deliverySuppressedMessageCount == 0);
assert(brokenMissing.undeliveredMessageCount == 1);
assert(~brokenMissing.remainingDeliverySuppressedAfterFailure);
assert(brokenMissing.partialDelivery);
assert(brokenMissing.stateRegressionCount == 2);
assert(brokenMissing.finalStateVersion == 5);
assert(strcmp(brokenMissing.terminationReason, ...
    'arrival-order-missing-message'));

recoveryAfterTimeout = model(1,2,100,true,true);
recoveryAfterOverflow = model(1,2,100,true,true);
assert(isequaln(recoveryAfterTimeout,baseline));
assert(isequaln(recoveryAfterOverflow,baseline));

bounded = model(20,6,1e6,true,true);
assert(isequal(bounded.networkDelayMs,[400 100 700 100 500 0]));
assert(isequal(bounded.arrivalTimeMs,[400 110 720 130 540 50]));
assert(isequal(bounded.arrivalSequence,[6 2 4 1 5 3]));
assert(isequal(bounded.deliverySequence,1:6));
assert(isequal(bounded.deliveryTimeBySequenceMs, ...
    [400 400 720 720 720 720]));
assert(bounded.reorderBufferHighWaterCount == 3);
assert(bounded.totalOrderingHoldMessageMs == 1730);
assert(bounded.completionTimeMs == 720);
assert(bounded.messageCount == 6);
assert(bounded.receivedMessageCount == 6);
assert(numel(bounded.arrivalTimeMs) == 6);
assert(numel(bounded.deliveryTimeBySequenceMs) == 6);
assert(all(isfinite(bounded.arrivalTimeMs)));
assert(all(isfinite(bounded.deliveryTimeBySequenceMs)));
assert(max(bounded.deliveryTimeBySequenceMs) <= ...
    bounded.maxDerivedTimeMs);
assert(bounded.calculationBounded);

boundedMissing = model(20,6,1e6,false,true);
assert(boundedMissing.timedOut);
assert(boundedMissing.failureTimeMs == 1000050);
assert(boundedMissing.failureTimeMs <= boundedMissing.maxDerivedTimeMs);

assert(strcmp(baseline.namedBrokenAssumption, ...
    'arrival order is send order'));
assert(strcmp(baseline.orderingScope,'single-sender sequence order'));
assert(baseline.singleSenderAssumed);
assert(baseline.senderSequenceNumbersTrusted);
assert(baseline.fixedBatchSizeKnown);
assert(baseline.applicationStateUpdateIsVersionAssignment);
assert(baseline.reorderBufferModeled);
assert(baseline.bufferCapacityApplicable);
assert(baseline.gapTimeoutApplicable);
assert(baseline.timeoutModeled);
assert(baseline.timeoutIsArithmeticClassification);
assert(~baseline.actualWaitPerformed);
assert(baseline.deliveryStopPolicyModeled);
assert(~baseline.actualAsynchronousCancellationPerformed);
assert(~baseline.rollbackModeled && ~baseline.actualRollbackPerformed);
assert(baseline.deliveredPrefixNotRolledBack);
assert(~baseline.recoveryModeled);
assert(baseline.recoveryRequiresReplayOrReevaluation);
assert(~baseline.retransmissionModeled);
assert(~baseline.duplicateHandlingModeled);
assert(~baseline.sequenceWrapModeled);
assert(~baseline.multipleSendersModeled);
assert(~baseline.causalOrderModeled);
assert(~baseline.totalOrderBroadcastModeled);
assert(~baseline.consensusModeled);
assert(~baseline.transportProtocolModeled);
assert(~baseline.networkIoPerformed && ~baseline.storageIoPerformed);
assert(~baseline.backgroundWorkStarted && ~baseline.physicalHardwareUsed);
assert(baseline.maxDelayScale == 20);
assert(baseline.maxReorderBufferCapacity == 6);
assert(baseline.maxGapTimeoutMs == 1e6);

assertThrows(@() model([],2,100,true,true), ...
    'P10:InvalidDelayScale');
assertThrows(@() model('slow',2,100,true,true), ...
    'P10:InvalidDelayScale');
assertThrows(@() model([1 2],2,100,true,true), ...
    'P10:InvalidDelayScale');
assertThrows(@() model(1 + 1i,2,100,true,true), ...
    'P10:InvalidDelayScale');
assertThrows(@() model(nan,2,100,true,true), ...
    'P10:InvalidDelayScale');
assertThrows(@() model(inf,2,100,true,true), ...
    'P10:InvalidDelayScale');
assertThrows(@() model(-eps,2,100,true,true), ...
    'P10:InvalidDelayScale');
assertThrows(@() model(20 + eps(20),2,100,true,true), ...
    'P10:InvalidDelayScale');

assertThrows(@() model(1,[],100,true,true), ...
    'P10:InvalidBufferCapacity');
assertThrows(@() model(1,'two',100,true,true), ...
    'P10:InvalidBufferCapacity');
assertThrows(@() model(1,[1 2],100,true,true), ...
    'P10:InvalidBufferCapacity');
assertThrows(@() model(1,2 + 1i,100,true,true), ...
    'P10:InvalidBufferCapacity');
assertThrows(@() model(1,nan,100,true,true), ...
    'P10:InvalidBufferCapacity');
assertThrows(@() model(1,inf,100,true,true), ...
    'P10:InvalidBufferCapacity');
assertThrows(@() model(1,-1,100,true,true), ...
    'P10:InvalidBufferCapacity');
assertThrows(@() model(1,7,100,true,true), ...
    'P10:InvalidBufferCapacity');
assertThrows(@() model(1,1.5,100,true,true), ...
    'P10:InvalidBufferCapacity');

assertThrows(@() model(1,2,[],true,true), ...
    'P10:InvalidGapTimeout');
assertThrows(@() model(1,2,'later',true,true), ...
    'P10:InvalidGapTimeout');
assertThrows(@() model(1,2,[10 20],true,true), ...
    'P10:InvalidGapTimeout');
assertThrows(@() model(1,2,1i,true,true), ...
    'P10:InvalidGapTimeout');
assertThrows(@() model(1,2,nan,true,true), ...
    'P10:InvalidGapTimeout');
assertThrows(@() model(1,2,inf,true,true), ...
    'P10:InvalidGapTimeout');
assertThrows(@() model(1,2,-eps,true,true), ...
    'P10:InvalidGapTimeout');
assertThrows(@() model(1,2,1e6 + eps(1e6),true,true), ...
    'P10:InvalidGapTimeout');

assertThrows(@() model(1,2,100,[],true), ...
    'P10:InvalidMessageAvailability');
assertThrows(@() model(1,2,100,'yes',true), ...
    'P10:InvalidMessageAvailability');
assertThrows(@() model(1,2,100,[true false],true), ...
    'P10:InvalidMessageAvailability');
assertThrows(@() model(1,2,100,1i,true), ...
    'P10:InvalidMessageAvailability');
assertThrows(@() model(1,2,100,nan,true), ...
    'P10:InvalidMessageAvailability');
assertThrows(@() model(1,2,100,inf,true), ...
    'P10:InvalidMessageAvailability');
assertThrows(@() model(1,2,100,-1,true), ...
    'P10:InvalidMessageAvailability');
assertThrows(@() model(1,2,100,2,true), ...
    'P10:InvalidMessageAvailability');
assertThrows(@() model(1,2,100,0.5,true), ...
    'P10:InvalidMessageAvailability');

assertThrows(@() model(1,2,100,true,[]), ...
    'P10:InvalidOrderingPolicy');
assertThrows(@() model(1,2,100,true,'strict'), ...
    'P10:InvalidOrderingPolicy');
assertThrows(@() model(1,2,100,true,[true false]), ...
    'P10:InvalidOrderingPolicy');
assertThrows(@() model(1,2,100,true,1i), ...
    'P10:InvalidOrderingPolicy');
assertThrows(@() model(1,2,100,true,nan), ...
    'P10:InvalidOrderingPolicy');
assertThrows(@() model(1,2,100,true,inf), ...
    'P10:InvalidOrderingPolicy');
assertThrows(@() model(1,2,100,true,-1), ...
    'P10:InvalidOrderingPolicy');
assertThrows(@() model(1,2,100,true,2), ...
    'P10:InvalidOrderingPolicy');
assertThrows(@() model(1,2,100,true,0.5), ...
    'P10:InvalidOrderingPolicy');

recoveredAfterMalformed = model();
assert(isequaln(recoveredAfterMalformed,baseline));

fprintf(['P10 checks passed: baseline, two sweeps, exact timeout/capacity ' ...
    'limits, broken raw delivery, malformed inputs, ordered-prefix failure, ' ...
    'no rollback/cancellation claims, recovery targets, isolation, and bounds.\n']);
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
error('P10:ExpectedErrorNotThrown', ...
    'Expected error %s was not thrown.',expectedIdentifier);
end
