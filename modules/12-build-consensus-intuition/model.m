function out = model(delayScale,quorumSize,decisionTimeoutMs, ...
    nodeFiveOnline,cancelPendingProposal)
%MODEL Deterministic one-round quorum-evidence model for P12.
% Five fixed nodes contribute at most one vote for one proposal. The model
% calculates when this evaluator observes a certificate and whether two
% threshold-sized certificates must intersect. A timeout or cancellation
% ends only this local observation window; later protocol progress is not
% modeled. The function starts no election, timer, message transport,
% storage engine, callback, or background work.

if nargin < 1
    delayScale = 1;
end
if nargin < 2
    quorumSize = 3;
end
if nargin < 3
    decisionTimeoutMs = 100;
end
if nargin < 4
    nodeFiveOnline = true;
end
if nargin < 5
    cancelPendingProposal = false;
end

nodeCount = 5;
majorityQuorumSize = floor(nodeCount / 2) + 1;
cancelRequestTimeMs = 20;
maxDelayScale = 20;
maxDecisionTimeoutMs = 1e6;
maxObservationEventCount = nodeCount + 2;
maxWitnessCertificateMembershipCount = 2 * nodeCount;
maxCertificateMaskCount = 4;
maxCertificateMaskMembershipSlots = maxCertificateMaskCount * nodeCount;
maxPotentialVoteTimeMs = 1202;
maxResolutionTimeMs = maxDecisionTimeoutMs;

if ~(isnumeric(delayScale) && isreal(delayScale) && ...
        isscalar(delayScale) && isfinite(delayScale) && ...
        delayScale >= 0 && delayScale <= maxDelayScale)
    error('P12:InvalidDelayScale', ...
        'delayScale must be a finite scalar from 0 through %.0f.', ...
        maxDelayScale);
end
if ~(isnumeric(quorumSize) && isreal(quorumSize) && ...
        isscalar(quorumSize) && isfinite(quorumSize) && ...
        quorumSize >= 1 && quorumSize <= nodeCount && ...
        quorumSize == fix(quorumSize))
    error('P12:InvalidQuorumSize', ...
        'quorumSize must be an integer from 1 through %d votes.', ...
        nodeCount);
end
if ~(isnumeric(decisionTimeoutMs) && isreal(decisionTimeoutMs) && ...
        isscalar(decisionTimeoutMs) && isfinite(decisionTimeoutMs) && ...
        decisionTimeoutMs >= 0 && ...
        decisionTimeoutMs <= maxDecisionTimeoutMs)
    error('P12:InvalidDecisionTimeout', ...
        ['decisionTimeoutMs must be a finite scalar from 0 through ' ...
        '%.0f ms.'],maxDecisionTimeoutMs);
end
if ~((islogical(nodeFiveOnline) || isnumeric(nodeFiveOnline)) && ...
        isreal(nodeFiveOnline) && isscalar(nodeFiveOnline) && ...
        isfinite(nodeFiveOnline) && ...
        (nodeFiveOnline == 0 || nodeFiveOnline == 1))
    error('P12:InvalidNodeAvailability', ...
        'nodeFiveOnline must be a scalar logical or numeric 0 or 1.');
end
if ~((islogical(cancelPendingProposal) || ...
        isnumeric(cancelPendingProposal)) && ...
        isreal(cancelPendingProposal) && ...
        isscalar(cancelPendingProposal) && ...
        isfinite(cancelPendingProposal) && ...
        (cancelPendingProposal == 0 || ...
        cancelPendingProposal == 1))
    error('P12:InvalidCancellationPolicy', ...
        ['cancelPendingProposal must be a scalar logical or ' ...
        'numeric 0 or 1.']);
end

delayScale = double(delayScale);
quorumSize = double(quorumSize);
decisionTimeoutMs = double(decisionTimeoutMs);
nodeFiveOnline = logical(nodeFiveOnline);
cancelPendingProposal = logical(cancelPendingProposal);

nodeId = 1:nodeCount;
baseOutboundDelayMs = [0 6 12 18 30];
voteProcessingTimeMs = [0 2 2 2 2];
baseReturnDelayMs = [0 6 12 18 30];
baseRoundTripDelayMs = baseOutboundDelayMs + baseReturnDelayMs;
potentialVoteTimeMs = ...
    delayScale * baseRoundTripDelayMs + voteProcessingTimeMs;
onlineMask = [true true true true nodeFiveOnline];
potentialVoteTimeMs(~onlineMask) = nan;
availableVoteCount = sum(onlineMask);

availableVoteRecords = [potentialVoteTimeMs(onlineMask).' ...
    nodeId(onlineMask).'];
availableVoteRecords = sortrows(availableVoteRecords,[1 2]);
orderedPotentialVoteTimeMs = availableVoteRecords(:,1).';
orderedVoterIds = availableVoteRecords(:,2).';
quorumReachable = availableVoteCount >= quorumSize;
if quorumReachable
    candidateDecisionTimeMs = ...
        orderedPotentialVoteTimeMs(quorumSize);
else
    candidateDecisionTimeMs = inf;
end

cancellationDeadlineMs = inf;
if cancelPendingProposal
    cancellationDeadlineMs = cancelRequestTimeMs;
end

% Complete quorum evidence wins an exact tie with timeout or cancellation.
if candidateDecisionTimeMs <= decisionTimeoutMs && ...
        candidateDecisionTimeMs <= cancellationDeadlineMs
    decided = true;
    timedOut = false;
    canceled = false;
    requestResolutionTimeMs = candidateDecisionTimeMs;
    outcome = 'decided';
elseif cancellationDeadlineMs <= decisionTimeoutMs
    decided = false;
    timedOut = false;
    canceled = true;
    requestResolutionTimeMs = cancellationDeadlineMs;
    outcome = 'canceled-pending';
else
    decided = false;
    timedOut = true;
    canceled = false;
    requestResolutionTimeMs = decisionTimeoutMs;
    outcome = 'timed-out';
end

voteObservedMask = onlineMask & ...
    potentialVoteTimeMs <= requestResolutionTimeMs;
observedVoteCount = sum(voteObservedMask);
unobservedOnlineVoteCount = availableVoteCount - observedVoteCount;
votesStillNeeded = max(0,quorumSize - observedVoteCount);

decisionCertificateMask = false(1,nodeCount);
decisionCertificateNodeIds = zeros(1,0);
decisionTimeMs = nan;
decisionLatencyMs = nan;
proposedValue = 65;
chosenValue = nan;
if decided
    decisionCertificateNodeIds = orderedVoterIds(1:quorumSize);
    decisionCertificateMask(decisionCertificateNodeIds) = true;
    decisionTimeMs = candidateDecisionTimeMs;
    decisionLatencyMs = candidateDecisionTimeMs;
    chosenValue = proposedValue;
end

observationTimeMs = unique([0 ...
    potentialVoteTimeMs(voteObservedMask) requestResolutionTimeMs]);
observationEventCount = numel(observationTimeMs);
observedVoteCumulative = zeros(1,observationEventCount);
for eventIndex = 1:observationEventCount
    observedVoteCumulative(eventIndex) = sum(onlineMask & ...
        potentialVoteTimeMs <= observationTimeMs(eventIndex) & ...
        potentialVoteTimeMs <= requestResolutionTimeMs);
end
quorumThresholdTrace = quorumSize * ...
    ones(1,observationEventCount);

% The two extreme threshold-sized sets realize the smallest possible
% intersection for a fixed membership of five nodes.
certificateANodeIds = 1:quorumSize;
certificateBNodeIds = (nodeCount - quorumSize + 1):nodeCount;
certificateAMask = false(1,nodeCount);
certificateBMask = false(1,nodeCount);
certificateAMask(certificateANodeIds) = true;
certificateBMask(certificateBNodeIds) = true;
certificateIntersectionMask = certificateAMask & certificateBMask;
certificateIntersectionNodeIds = find(certificateIntersectionMask);
certificateIntersectionCount = sum(certificateIntersectionMask);
minimumQuorumIntersectionNodes = max(0,2 * quorumSize - nodeCount);
safeMajorityQuorum = 2 * quorumSize > nodeCount;
oneVotePerNodePerTermAssumed = true;
hypotheticalConflictingDecisionsPossible = ...
    certificateIntersectionCount == 0;
conflictingCertificatesBlockedByIntersection = ...
    safeMajorityQuorum && oneVotePerNodePerTermAssumed;
fixedProposerOnlineAssumed = true;
unavailableFollowerTolerance = nodeCount - quorumSize;

finitePotentialVoteTimesMs = potentialVoteTimeMs(onlineMask);
potentialVoteSpreadMs = max(finitePotentialVoteTimesMs) - ...
    min(finitePotentialVoteTimesMs);
if isfinite(candidateDecisionTimeMs)
    potentialQuorumTimeMs = candidateDecisionTimeMs;
    timeoutMarginMs = decisionTimeoutMs - candidateDecisionTimeMs;
else
    potentialQuorumTimeMs = nan;
    timeoutMarginMs = nan;
end

out.nodeCount = nodeCount;
out.nodeId = nodeId;
out.delayScale = delayScale;
out.quorumSize = quorumSize;
out.majorityQuorumSize = majorityQuorumSize;
out.decisionTimeoutMs = decisionTimeoutMs;
out.nodeFiveOnline = nodeFiveOnline;
out.cancelPendingProposal = cancelPendingProposal;
out.cancelRequestTimeMs = cancelRequestTimeMs;
out.baseOutboundDelayMs = baseOutboundDelayMs;
out.voteProcessingTimeMs = voteProcessingTimeMs;
out.baseReturnDelayMs = baseReturnDelayMs;
out.baseRoundTripDelayMs = baseRoundTripDelayMs;
out.potentialVoteTimeMs = potentialVoteTimeMs;
out.onlineMask = onlineMask;
out.offlineNodeIds = find(~onlineMask);
out.availableVoteCount = availableVoteCount;
out.orderedPotentialVoteTimeMs = orderedPotentialVoteTimeMs;
out.orderedVoterIds = orderedVoterIds;
out.quorumReachable = quorumReachable;
out.potentialQuorumTimeMs = potentialQuorumTimeMs;
out.timeoutMarginMs = timeoutMarginMs;
out.requestResolutionTimeMs = requestResolutionTimeMs;
out.voteObservedMask = voteObservedMask;
out.observedVoteCount = observedVoteCount;
out.unobservedOnlineVoteCount = unobservedOnlineVoteCount;
out.votesStillNeeded = votesStillNeeded;
out.decisionCertificateMask = decisionCertificateMask;
out.decisionCertificateNodeIds = decisionCertificateNodeIds;
out.decisionTimeMs = decisionTimeMs;
out.decisionLatencyMs = decisionLatencyMs;
out.proposedValue = proposedValue;
out.chosenValue = chosenValue;
out.decided = decided;
out.timedOut = timedOut;
out.canceled = canceled;
out.outcome = outcome;
out.observationTimeMs = observationTimeMs;
out.observationEventCount = observationEventCount;
out.observedVoteCumulative = observedVoteCumulative;
out.quorumThresholdTrace = quorumThresholdTrace;
out.certificateANodeIds = certificateANodeIds;
out.certificateBNodeIds = certificateBNodeIds;
out.certificateAMask = certificateAMask;
out.certificateBMask = certificateBMask;
out.certificateIntersectionMask = certificateIntersectionMask;
out.certificateIntersectionNodeIds = ...
    certificateIntersectionNodeIds;
out.certificateIntersectionCount = certificateIntersectionCount;
out.minimumQuorumIntersectionNodes = ...
    minimumQuorumIntersectionNodes;
out.safeMajorityQuorum = safeMajorityQuorum;
out.oneVotePerNodePerTermAssumed = ...
    oneVotePerNodePerTermAssumed;
out.hypotheticalConflictingDecisionsPossible = ...
    hypotheticalConflictingDecisionsPossible;
out.conflictingCertificatesBlockedByIntersection = ...
    conflictingCertificatesBlockedByIntersection;
out.fixedProposerOnlineAssumed = fixedProposerOnlineAssumed;
out.unavailableFollowerTolerance = unavailableFollowerTolerance;
out.potentialVoteSpreadMs = potentialVoteSpreadMs;
out.voteAccountingConserved = ...
    observedVoteCount + unobservedOnlineVoteCount == ...
    availableVoteCount;
out.quorumCertificateComplete = decided && ...
    sum(decisionCertificateMask) == quorumSize;
out.partialObservedVotesDoNotProveDecision = ~decided && ...
    observedVoteCount < quorumSize && isnan(chosenValue);
out.decisionMeansCertificateObservedByEvaluator = true;
out.postResolutionProtocolProgressModeled = false;
out.quorumEvidenceWinsExactTie = true;
out.decisionWonTimeoutTie = decided && ...
    candidateDecisionTimeMs == decisionTimeoutMs;
out.decisionWonCancellationTie = decided && ...
    cancelPendingProposal && ...
    candidateDecisionTimeMs == cancelRequestTimeMs;
out.cancellationRequestModeled = cancelPendingProposal;
out.cancellationHasTimeoutTiePrecedence = true;
out.cancellationWonTimeoutTie = canceled && ...
    cancelPendingProposal && ...
    cancellationDeadlineMs == decisionTimeoutMs;
out.cancellationTookEffectOnlyWhilePending = canceled;
out.cancellationCouldNotEraseObservedCertificate = ...
    cancelPendingProposal && decided && ...
    candidateDecisionTimeMs <= cancelRequestTimeMs;
out.cancellationClosesEvaluatorWindowOnly = true;
out.timeoutIsArithmeticClassification = true;
out.actualWallClockWaitPerformed = false;
out.actualAsynchronousCancellationPerformed = false;
out.rollbackModeled = false;
out.actualRollbackPerformed = false;
out.observedVotesNotRolledBack = true;
out.observedCertificateNotErasedByLateCancellation = true;
out.recoveryModeled = false;
out.retryModeled = false;
out.freshEvaluationRequiredForRecoveryTarget = true;
out.singleRoundQuorumEvidenceModeled = true;
out.fullConsensusProtocolModeled = false;
out.leaderElectionModeled = false;
out.logReplicationModeled = false;
out.valueApplicationModeled = false;
out.membershipChangeModeled = false;
out.partitionExecutionModeled = false;
out.competingProposalExecutionModeled = false;
out.certificateGeometryOnly = true;
out.fixedMembershipAssumed = true;
out.crashStopAvailabilityOnly = true;
out.byzantineBehaviorModeled = false;
out.networkIoPerformed = false;
out.storageIoPerformed = false;
out.durableStateModeled = false;
out.backgroundWorkStarted = false;
out.physicalHardwareUsed = false;
out.maxDelayScale = maxDelayScale;
out.maxDecisionTimeoutMs = maxDecisionTimeoutMs;
out.maxObservationEventCount = maxObservationEventCount;
out.maxWitnessCertificateMembershipCount = ...
    maxWitnessCertificateMembershipCount;
out.maxCertificateMaskCount = maxCertificateMaskCount;
out.maxCertificateMaskMembershipSlots = ...
    maxCertificateMaskMembershipSlots;
out.maxPotentialVoteTimeMs = maxPotentialVoteTimeMs;
out.maxResolutionTimeMs = maxResolutionTimeMs;
out.calculationBounded = true;
out.derivedTimeWithinBound = ...
    all(finitePotentialVoteTimesMs <= maxPotentialVoteTimeMs) && ...
    requestResolutionTimeMs <= maxResolutionTimeMs;
end
