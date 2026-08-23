function out = model(delayScale,reorderBufferCapacity,gapTimeoutMs, ...
    messageThreeAvailable,preserveSequenceOrder)
%MODEL Deterministic single-sender message-ordering model for P10.
% Six versioned messages traverse synthetic paths. A strict receiver uses
% sequence numbers, a bounded reorder buffer, and a gap deadline. This is
% finite arithmetic; it starts no transport, timer, task, or device work.

if nargin < 1
    delayScale = 1;
end
if nargin < 2
    reorderBufferCapacity = 2;
end
if nargin < 3
    gapTimeoutMs = 100;
end
if nargin < 4
    messageThreeAvailable = true;
end
if nargin < 5
    preserveSequenceOrder = true;
end

messageCount = 6;
missingMessageIndex = 3;
initialStateVersion = 0;
sendIntervalMs = 10;
sequence = 1:messageCount;
sendTimeMs = (sequence - 1) * sendIntervalMs;
baseNetworkDelayMs = [20 5 35 5 25 0];
maxDelayScale = 20;
maxReorderBufferCapacity = messageCount;
maxGapTimeoutMs = 1e6;
maxDerivedTimeMs = 1.001e6;

if ~(isnumeric(delayScale) && isreal(delayScale) && ...
        isscalar(delayScale) && isfinite(delayScale) && ...
        delayScale >= 0 && delayScale <= maxDelayScale)
    error('P10:InvalidDelayScale', ...
        'delayScale must be a finite scalar from 0 through %.0f.', ...
        maxDelayScale);
end
if ~(isnumeric(reorderBufferCapacity) && ...
        isreal(reorderBufferCapacity) && ...
        isscalar(reorderBufferCapacity) && ...
        isfinite(reorderBufferCapacity) && ...
        reorderBufferCapacity >= 0 && ...
        reorderBufferCapacity <= maxReorderBufferCapacity && ...
        reorderBufferCapacity == fix(reorderBufferCapacity))
    error('P10:InvalidBufferCapacity', ...
        'reorderBufferCapacity must be an integer scalar from 0 through %d.', ...
        maxReorderBufferCapacity);
end
if ~(isnumeric(gapTimeoutMs) && isreal(gapTimeoutMs) && ...
        isscalar(gapTimeoutMs) && isfinite(gapTimeoutMs) && ...
        gapTimeoutMs >= 0 && gapTimeoutMs <= maxGapTimeoutMs)
    error('P10:InvalidGapTimeout', ...
        'gapTimeoutMs must be a finite scalar from 0 through %.0f ms.', ...
        maxGapTimeoutMs);
end
if ~((islogical(messageThreeAvailable) || ...
        isnumeric(messageThreeAvailable)) && ...
        isreal(messageThreeAvailable) && ...
        isscalar(messageThreeAvailable) && ...
        isfinite(messageThreeAvailable) && ...
        (messageThreeAvailable == 0 || messageThreeAvailable == 1))
    error('P10:InvalidMessageAvailability', ...
        'messageThreeAvailable must be a scalar logical or numeric 0 or 1.');
end
if ~((islogical(preserveSequenceOrder) || ...
        isnumeric(preserveSequenceOrder)) && ...
        isreal(preserveSequenceOrder) && ...
        isscalar(preserveSequenceOrder) && ...
        isfinite(preserveSequenceOrder) && ...
        (preserveSequenceOrder == 0 || preserveSequenceOrder == 1))
    error('P10:InvalidOrderingPolicy', ...
        'preserveSequenceOrder must be a scalar logical or numeric 0 or 1.');
end

delayScale = double(delayScale);
reorderBufferCapacity = double(reorderBufferCapacity);
gapTimeoutMs = double(gapTimeoutMs);
messageThreeAvailable = logical(messageThreeAvailable);
preserveSequenceOrder = logical(preserveSequenceOrder);

networkDelayMs = delayScale * baseNetworkDelayMs;
arrivalTimeMs = sendTimeMs + networkDelayMs;
receivedMask = true(1,messageCount);
receivedMask(missingMessageIndex) = messageThreeAvailable;
receivedSequenceInSendOrder = sequence(receivedMask);
receivedArrivalTimeInSendOrderMs = arrivalTimeMs(receivedMask);

% Equal analytical arrival times are processed by lower sequence number.
% The explicit second sort key avoids relying on sort stability.
arrivalEvents = [receivedArrivalTimeInSendOrderMs(:), ...
    receivedSequenceInSendOrder(:)];
arrivalEvents = sortrows(arrivalEvents,[1 2]);
arrivalEventTimeMs = arrivalEvents(:,1).';
arrivalSequence = arrivalEvents(:,2).';
receivedMessageCount = numel(arrivalSequence);
arrivalInversionCount = countInversions(arrivalSequence);
arrivalOrderMatchesSendOrder = ...
    isequal(arrivalSequence,receivedSequenceInSendOrder);

deliverySequenceStorage = nan(1,messageCount);
deliveryEventTimeStorageMs = nan(1,messageCount);
deliveryTimeBySequenceMs = nan(1,messageCount);
bufferOccupancyAfterEvent = nan(1,receivedMessageCount);
buffered = false(1,messageCount);
deliveredMessageCount = 0;
processedEventCount = 0;
reorderBufferHighWaterCount = 0;
expectedSequence = 1;
gapActive = false;
gapStartTimeMs = nan;
gapDeadlineMs = nan;
lastGapStartTimeMs = nan;
lastGapDeadlineMs = nan;
timeoutExpectedSequence = nan;
rejectedSequence = nan;
timedOut = false;
bufferOverflow = false;
failureTimeMs = nan;
terminationReason = 'complete-ordered';

if preserveSequenceOrder
    for eventIndex = 1:receivedMessageCount
        eventTimeMs = arrivalEventTimeMs(eventIndex);

        % A message arriving exactly at the deadline is eligible. A later
        % event first observes the already-expired analytical deadline.
        if gapActive && eventTimeMs > gapDeadlineMs
            timedOut = true;
            failureTimeMs = gapDeadlineMs;
            timeoutExpectedSequence = expectedSequence;
            terminationReason = 'gap-timeout';
            break;
        end

        processedEventCount = eventIndex;
        currentSequence = arrivalSequence(eventIndex);
        if currentSequence == expectedSequence
            deliveredMessageCount = deliveredMessageCount + 1;
            deliverySequenceStorage(deliveredMessageCount) = ...
                currentSequence;
            deliveryEventTimeStorageMs(deliveredMessageCount) = ...
                eventTimeMs;
            deliveryTimeBySequenceMs(currentSequence) = eventTimeMs;
            expectedSequence = expectedSequence + 1;

            % Drain every contiguous successor already held in the buffer.
            for drainAttempt = 1:messageCount
                if expectedSequence > messageCount || ...
                        ~buffered(expectedSequence)
                    break;
                end
                buffered(expectedSequence) = false;
                deliveredMessageCount = deliveredMessageCount + 1;
                deliverySequenceStorage(deliveredMessageCount) = ...
                    expectedSequence;
                deliveryEventTimeStorageMs(deliveredMessageCount) = ...
                    eventTimeMs;
                deliveryTimeBySequenceMs(expectedSequence) = eventTimeMs;
                expectedSequence = expectedSequence + 1;
            end

            if any(buffered)
                gapActive = true;
                gapStartTimeMs = min(arrivalTimeMs(buffered));
                gapDeadlineMs = gapStartTimeMs + gapTimeoutMs;
                lastGapStartTimeMs = gapStartTimeMs;
                lastGapDeadlineMs = gapDeadlineMs;
            else
                gapActive = false;
                gapStartTimeMs = nan;
                gapDeadlineMs = nan;
            end
        elseif currentSequence > expectedSequence
            if sum(buffered) >= reorderBufferCapacity
                bufferOverflow = true;
                failureTimeMs = eventTimeMs;
                rejectedSequence = currentSequence;
                terminationReason = 'buffer-overflow';
                bufferOccupancyAfterEvent(eventIndex) = sum(buffered);
                break;
            end
            buffered(currentSequence) = true;
            reorderBufferHighWaterCount = max( ...
                reorderBufferHighWaterCount,sum(buffered));
            if ~gapActive
                gapActive = true;
                gapStartTimeMs = eventTimeMs;
                gapDeadlineMs = gapStartTimeMs + gapTimeoutMs;
                lastGapStartTimeMs = gapStartTimeMs;
                lastGapDeadlineMs = gapDeadlineMs;
            end
        end

        bufferOccupancyAfterEvent(eventIndex) = sum(buffered);
        if gapActive && gapDeadlineMs <= eventTimeMs
            timedOut = true;
            failureTimeMs = gapDeadlineMs;
            timeoutExpectedSequence = expectedSequence;
            terminationReason = 'gap-timeout';
            break;
        end
    end

    if ~timedOut && ~bufferOverflow && any(buffered)
        timedOut = true;
        failureTimeMs = gapDeadlineMs;
        timeoutExpectedSequence = expectedSequence;
        terminationReason = 'gap-timeout';
    elseif ~timedOut && ~bufferOverflow
        terminationReason = 'complete-ordered';
    end
else
    deliveredMessageCount = receivedMessageCount;
    deliverySequenceStorage(1:deliveredMessageCount) = arrivalSequence;
    deliveryEventTimeStorageMs(1:deliveredMessageCount) = ...
        arrivalEventTimeMs;
    for eventIndex = 1:receivedMessageCount
        currentSequence = arrivalSequence(eventIndex);
        deliveryTimeBySequenceMs(currentSequence) = ...
            arrivalEventTimeMs(eventIndex);
    end
    bufferOccupancyAfterEvent(:) = 0;
    processedEventCount = receivedMessageCount;
    expectedSequence = nan;
    if messageThreeAvailable
        terminationReason = 'arrival-order-delivery';
    else
        terminationReason = 'arrival-order-missing-message';
    end
end

deliverySequence = ...
    deliverySequenceStorage(1:deliveredMessageCount);
deliveryEventTimeMs = ...
    deliveryEventTimeStorageMs(1:deliveredMessageCount);
deliveryInversionCount = countInversions(deliverySequence);
stateRegressionCount = sum(diff(deliverySequence) < 0);
if deliveredMessageCount > 0
    finalStateVersion = deliverySequence(end);
else
    finalStateVersion = initialStateVersion;
end

holdTimeBySequenceMs = nan(1,messageCount);
deliveredMask = ~isnan(deliveryTimeBySequenceMs);
holdTimeBySequenceMs(deliveredMask) = ...
    deliveryTimeBySequenceMs(deliveredMask) - ...
    arrivalTimeMs(deliveredMask);
deliveredHoldTimeMs = holdTimeBySequenceMs(deliveredMask);
totalOrderingHoldMessageMs = sum(deliveredHoldTimeMs);
if isempty(deliveredHoldTimeMs)
    meanOrderingHoldMs = nan;
    maxOrderingHoldMs = 0;
else
    meanOrderingHoldMs = mean(deliveredHoldTimeMs);
    maxOrderingHoldMs = max(deliveredHoldTimeMs);
end

allMessagesDelivered = deliveredMessageCount == messageCount;
deliveredPrefixOrdered = isequal( ...
    deliverySequence,sequence(1:deliveredMessageCount));
completeOrderedDelivery = allMessagesDelivered && ...
    isequal(deliverySequence,sequence);
if allMessagesDelivered
    completionTimeMs = max(deliveryEventTimeMs);
else
    completionTimeMs = nan;
end
streamTerminated = timedOut || bufferOverflow;
missingMessageCount = messageCount - receivedMessageCount;
deliverySuppressedMessageCount = ...
    receivedMessageCount - deliveredMessageCount;
undeliveredMessageCount = messageCount - deliveredMessageCount;
bufferedAtTerminationCount = sum(buffered);
inFlightAtTerminationCount = max( ...
    receivedMessageCount - processedEventCount,0);
remainingDeliverySuppressedAfterFailure = ...
    streamTerminated && deliverySuppressedMessageCount > 0;
partialDelivery = deliveredMessageCount > 0 && ...
    deliveredMessageCount < messageCount;
stateVersionTrace = [initialStateVersion deliverySequence];

out = struct();
out.delayScale = delayScale;
out.reorderBufferCapacity = reorderBufferCapacity;
out.gapTimeoutMs = gapTimeoutMs;
out.messageThreeAvailable = messageThreeAvailable;
out.preserveSequenceOrder = preserveSequenceOrder;
out.messageCount = messageCount;
out.missingMessageIndex = missingMessageIndex;
out.sequence = sequence;
out.sendIntervalMs = sendIntervalMs;
out.sendTimeMs = sendTimeMs;
out.baseNetworkDelayMs = baseNetworkDelayMs;
out.networkDelayMs = networkDelayMs;
out.arrivalTimeMs = arrivalTimeMs;
out.receivedMask = receivedMask;
out.receivedSequenceInSendOrder = receivedSequenceInSendOrder;
out.receivedArrivalTimeInSendOrderMs = ...
    receivedArrivalTimeInSendOrderMs;
out.arrivalEventTimeMs = arrivalEventTimeMs;
out.arrivalSequence = arrivalSequence;
out.receivedMessageCount = receivedMessageCount;
out.arrivalInversionCount = arrivalInversionCount;
out.arrivalOrderMatchesSendOrder = arrivalOrderMatchesSendOrder;
out.deliverySequence = deliverySequence;
out.deliveryEventTimeMs = deliveryEventTimeMs;
out.deliveryTimeBySequenceMs = deliveryTimeBySequenceMs;
out.deliveryInversionCount = deliveryInversionCount;
out.deliveredPrefixOrdered = deliveredPrefixOrdered;
out.completeOrderedDelivery = completeOrderedDelivery;
out.deliveredMessageCount = deliveredMessageCount;
out.allMessagesDelivered = allMessagesDelivered;
out.completionTimeMs = completionTimeMs;
out.holdTimeBySequenceMs = holdTimeBySequenceMs;
out.totalOrderingHoldMessageMs = totalOrderingHoldMessageMs;
out.meanOrderingHoldMs = meanOrderingHoldMs;
out.maxOrderingHoldMs = maxOrderingHoldMs;
out.bufferOccupancyAfterEvent = bufferOccupancyAfterEvent;
out.reorderBufferHighWaterCount = reorderBufferHighWaterCount;
out.bufferedAtTerminationCount = bufferedAtTerminationCount;
out.expectedSequenceAtTermination = expectedSequence;
out.gapActiveAtTermination = gapActive;
out.gapStartTimeMs = gapStartTimeMs;
out.gapDeadlineMs = gapDeadlineMs;
out.lastGapStartTimeMs = lastGapStartTimeMs;
out.lastGapDeadlineMs = lastGapDeadlineMs;
out.timedOut = timedOut;
out.timeoutExpectedSequence = timeoutExpectedSequence;
out.bufferOverflow = bufferOverflow;
out.rejectedSequence = rejectedSequence;
out.failureTimeMs = failureTimeMs;
out.streamTerminated = streamTerminated;
out.terminationReason = terminationReason;
out.processedEventCount = processedEventCount;
out.inFlightAtTerminationCount = inFlightAtTerminationCount;
out.missingMessageCount = missingMessageCount;
out.deliverySuppressedMessageCount = ...
    deliverySuppressedMessageCount;
out.undeliveredMessageCount = undeliveredMessageCount;
out.remainingDeliverySuppressedAfterFailure = ...
    remainingDeliverySuppressedAfterFailure;
out.partialDelivery = partialDelivery;
out.initialStateVersion = initialStateVersion;
out.stateVersionTrace = stateVersionTrace;
out.finalStateVersion = finalStateVersion;
out.latestGeneratedVersion = messageCount;
out.stateRegressionCount = stateRegressionCount;
out.finalStateIsLatest = finalStateVersion == messageCount;
out.namedBrokenAssumption = 'arrival order is send order';
out.orderingScope = 'single-sender sequence order';
out.arrivalTieBreakRule = ...
    'lower sequence first at equal analytical arrival time';
out.singleSenderAssumed = true;
out.senderSequenceNumbersTrusted = true;
out.fixedBatchSizeKnown = true;
out.applicationStateUpdateIsVersionAssignment = true;
out.reorderBufferModeled = preserveSequenceOrder;
out.bufferCapacityApplicable = preserveSequenceOrder;
out.gapTimeoutApplicable = preserveSequenceOrder;
out.timeoutModeled = preserveSequenceOrder;
out.timeoutIsArithmeticClassification = true;
out.actualWaitPerformed = false;
out.deliveryStopPolicyModeled = preserveSequenceOrder;
out.actualAsynchronousCancellationPerformed = false;
out.rollbackModeled = false;
out.actualRollbackPerformed = false;
out.deliveredPrefixNotRolledBack = true;
out.recoveryModeled = false;
out.recoveryRequiresReplayOrReevaluation = true;
out.retransmissionModeled = false;
out.duplicateHandlingModeled = false;
out.sequenceWrapModeled = false;
out.multipleSendersModeled = false;
out.causalOrderModeled = false;
out.totalOrderBroadcastModeled = false;
out.consensusModeled = false;
out.transportProtocolModeled = false;
out.networkIoPerformed = false;
out.backgroundWorkStarted = false;
out.storageIoPerformed = false;
out.physicalHardwareUsed = false;
out.maxDelayScale = maxDelayScale;
out.maxReorderBufferCapacity = maxReorderBufferCapacity;
out.maxGapTimeoutMs = maxGapTimeoutMs;
out.maxDerivedTimeMs = maxDerivedTimeMs;
out.calculationBounded = true;
end

function count = countInversions(values)
%COUNTINVERSIONS Transparent pairwise inversion count for at most six IDs.
count = 0;
for leftIndex = 1:numel(values)
    for rightIndex = leftIndex + 1:numel(values)
        if values(leftIndex) > values(rightIndex)
            count = count + 1;
        end
    end
end
end
