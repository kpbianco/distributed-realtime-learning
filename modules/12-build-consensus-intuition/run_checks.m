function run_checks
%RUN_CHECKS Verify P12 quorum timing, intersection, and failure boundaries.

%% Deterministic baseline and independent arithmetic
baseline = model(1,3,100,true,false);
repeated = model(1,3,100,true,false);
defaults = model();
typed = model(single(1),uint8(3),uint16(100),uint8(1),uint8(0));

assert(isequaln(repeated,baseline));
assert(isequaln(defaults,baseline));
assert(isequaln(typed,baseline));
assert(baseline.nodeCount == 5);
assert(isequal(baseline.nodeId,1:5));
assert(baseline.delayScale == 1);
assert(baseline.quorumSize == 3);
assert(baseline.majorityQuorumSize == 3);
assert(baseline.decisionTimeoutMs == 100);
assert(baseline.nodeFiveOnline);
assert(~baseline.cancelPendingProposal);
assert(baseline.cancelRequestTimeMs == 20);

expectedOutboundMs = [0 6 12 18 30];
expectedProcessingMs = [0 2 2 2 2];
expectedReturnMs = [0 6 12 18 30];
expectedRoundTripMs = expectedOutboundMs + expectedReturnMs;
expectedVoteTimeMs = expectedRoundTripMs + expectedProcessingMs;
assert(isequal(baseline.baseOutboundDelayMs,expectedOutboundMs));
assert(isequal(baseline.voteProcessingTimeMs,expectedProcessingMs));
assert(isequal(baseline.baseReturnDelayMs,expectedReturnMs));
assert(isequal(baseline.baseRoundTripDelayMs,expectedRoundTripMs));
assert(isequal(expectedRoundTripMs,[0 12 24 36 60]));
assert(isequal(expectedVoteTimeMs,[0 14 26 38 62]));
assert(isequal(baseline.potentialVoteTimeMs,expectedVoteTimeMs));
assert(isequal(baseline.onlineMask,true(1,5)));
assert(isempty(baseline.offlineNodeIds));
assert(baseline.availableVoteCount == 5);
assert(isequal(baseline.orderedPotentialVoteTimeMs,expectedVoteTimeMs));
assert(isequal(baseline.orderedVoterIds,1:5));
assert(baseline.quorumReachable);
assert(baseline.potentialQuorumTimeMs == expectedVoteTimeMs(3));
assert(baseline.timeoutMarginMs == 74);

assert(baseline.decided);
assert(~baseline.timedOut);
assert(~baseline.canceled);
assert(strcmp(baseline.outcome,'decided'));
assert(baseline.requestResolutionTimeMs == 26);
assert(baseline.decisionTimeMs == 26);
assert(baseline.decisionLatencyMs == 26);
assert(baseline.proposedValue == 65);
assert(baseline.chosenValue == 65);
assert(isequal(baseline.voteObservedMask,[true true true false false]));
assert(baseline.observedVoteCount == 3);
assert(baseline.unobservedOnlineVoteCount == 2);
assert(baseline.votesStillNeeded == 0);
assert(isequal(baseline.decisionCertificateNodeIds,1:3));
assert(isequal(baseline.decisionCertificateMask, ...
    [true true true false false]));
assert(baseline.quorumCertificateComplete);
assert(baseline.voteAccountingConserved);
assert(~baseline.partialObservedVotesDoNotProveDecision);
assert(baseline.decisionMeansCertificateObservedByEvaluator);
assert(~baseline.postResolutionProtocolProgressModeled);

assert(isequal(baseline.observationTimeMs,[0 14 26]));
assert(isequal(baseline.observedVoteCumulative,[1 2 3]));
assert(isequal(baseline.quorumThresholdTrace,[3 3 3]));
assert(all(diff(baseline.observationTimeMs) > 0));
assert(all(diff(baseline.observedVoteCumulative) > 0));
assert(baseline.observedVoteCumulative(end) == ...
    baseline.observedVoteCount);

expectedCertificateA = [1 2 3];
expectedCertificateB = [3 4 5];
expectedIntersection = intersect(expectedCertificateA, ...
    expectedCertificateB);
assert(isequal(baseline.certificateANodeIds,expectedCertificateA));
assert(isequal(baseline.certificateBNodeIds,expectedCertificateB));
assert(isequal(baseline.certificateAMask,[true true true false false]));
assert(isequal(baseline.certificateBMask,[false false true true true]));
assert(isequal(baseline.certificateIntersectionNodeIds, ...
    expectedIntersection));
assert(isequal(expectedIntersection,3));
assert(baseline.certificateIntersectionCount == 1);
assert(baseline.minimumQuorumIntersectionNodes == ...
    max(0,2 * baseline.quorumSize - baseline.nodeCount));
assert(baseline.minimumQuorumIntersectionNodes == 1);
assert(baseline.safeMajorityQuorum);
assert(baseline.oneVotePerNodePerTermAssumed);
assert(~baseline.hypotheticalConflictingDecisionsPossible);
assert(baseline.conflictingCertificatesBlockedByIntersection);
assert(baseline.fixedProposerOnlineAssumed);
assert(baseline.unavailableFollowerTolerance == 2);
assert(baseline.potentialVoteSpreadMs == 62);

fractional = model(0.25,3,37.5,true,false);
assert(fractional.delayScale == 0.25);
assert(fractional.decisionTimeoutMs == 37.5);
assert(isequal(fractional.potentialVoteTimeMs,[0 5 8 11 17]));
assert(fractional.decided);
assert(fractional.decisionTimeMs == 8);
assert(fractional.minimumQuorumIntersectionNodes == 1);

%% Deterministic tie order and zero-delay limiting case
zeroDelay = model(0,3,100,true,false);
assert(isequal(zeroDelay.potentialVoteTimeMs,[0 2 2 2 2]));
assert(isequal(zeroDelay.orderedVoterIds,1:5));
assert(isequal(zeroDelay.orderedPotentialVoteTimeMs,[0 2 2 2 2]));
assert(zeroDelay.decisionTimeMs == 2);
assert(isequal(zeroDelay.decisionCertificateNodeIds,1:3));
assert(zeroDelay.observedVoteCount == 5);
assert(zeroDelay.unobservedOnlineVoteCount == 0);
assert(isequal(zeroDelay.observationTimeMs,[0 2]));
assert(isequal(zeroDelay.observedVoteCumulative,[1 5]));

%% Sweep 1: round-trip delay scale only
delayScales = [0 0.5 1 2];
delayDecisionLatencyMs = zeros(size(delayScales));
delayVoteSpreadMs = zeros(size(delayScales));
delayObservedVotes = zeros(size(delayScales));
for caseIndex = 1:numel(delayScales)
    current = model(delayScales(caseIndex),3,100,true,false);
    assert(current.quorumSize == 3);
    assert(current.decisionTimeoutMs == 100);
    assert(current.nodeFiveOnline);
    assert(~current.cancelPendingProposal);
    assert(current.decided);
    assert(current.safeMajorityQuorum);
    assert(current.minimumQuorumIntersectionNodes == 1);
    delayDecisionLatencyMs(caseIndex) = current.decisionLatencyMs;
    delayVoteSpreadMs(caseIndex) = current.potentialVoteSpreadMs;
    delayObservedVotes(caseIndex) = current.observedVoteCount;
end
assert(isequal(delayDecisionLatencyMs,[2 14 26 50]));
assert(isequal(delayVoteSpreadMs,[2 32 62 122]));
assert(isequal(delayObservedVotes,[5 3 3 3]));

%% Sweep 2: quorum size only
quorumSizes = [2 3 4 5];
quorumDecisionLatencyMs = zeros(size(quorumSizes));
quorumMinimumIntersection = zeros(size(quorumSizes));
quorumUnavailableFollowerTolerance = zeros(size(quorumSizes));
quorumSafe = false(size(quorumSizes));
for caseIndex = 1:numel(quorumSizes)
    current = model(1,quorumSizes(caseIndex),100,true,false);
    assert(current.delayScale == 1);
    assert(current.decisionTimeoutMs == 100);
    assert(current.nodeFiveOnline);
    assert(~current.cancelPendingProposal);
    assert(current.decided);
    quorumDecisionLatencyMs(caseIndex) = current.decisionLatencyMs;
    quorumMinimumIntersection(caseIndex) = ...
        current.minimumQuorumIntersectionNodes;
    assert(current.fixedProposerOnlineAssumed);
    quorumUnavailableFollowerTolerance(caseIndex) = ...
        current.unavailableFollowerTolerance;
    quorumSafe(caseIndex) = current.safeMajorityQuorum;
end
assert(isequal(quorumDecisionLatencyMs,[14 26 38 62]));
assert(isequal(quorumMinimumIntersection,[0 1 3 5]));
assert(isequal(quorumUnavailableFollowerTolerance,[3 2 1 0]));
assert(isequal(quorumSafe,[false true true true]));

%% Deliberately broken below-majority threshold
broken = model(1,2,100,true,false);
assert(broken.decided);
assert(broken.decisionTimeMs == 14);
assert(isequal(broken.decisionCertificateNodeIds,[1 2]));
assert(isequal(broken.certificateANodeIds,[1 2]));
assert(isequal(broken.certificateBNodeIds,[4 5]));
assert(isequal(broken.certificateAMask,[true true false false false]));
assert(isequal(broken.certificateBMask,[false false false true true]));
assert(isempty(broken.certificateIntersectionNodeIds));
assert(broken.certificateIntersectionCount == 0);
assert(broken.minimumQuorumIntersectionNodes == 0);
assert(~broken.safeMajorityQuorum);
assert(broken.hypotheticalConflictingDecisionsPossible);
assert(~broken.conflictingCertificatesBlockedByIntersection);
assert(broken.certificateGeometryOnly);
assert(~broken.partitionExecutionModeled);
assert(~broken.competingProposalExecutionModeled);

singleVote = model(1,1,0,true,false);
assert(singleVote.decided);
assert(singleVote.decisionTimeMs == 0);
assert(singleVote.decisionWonTimeoutTie);
assert(isequal(singleVote.decisionCertificateNodeIds,1));
assert(singleVote.minimumQuorumIntersectionNodes == 0);
assert(singleVote.hypotheticalConflictingDecisionsPossible);

%% Timeout and availability boundaries
exactTimeoutBoundary = model(1,4,38,true,false);
assert(exactTimeoutBoundary.decided);
assert(exactTimeoutBoundary.decisionTimeMs == 38);
assert(exactTimeoutBoundary.decisionWonTimeoutTie);
assert(exactTimeoutBoundary.observedVoteCount == 4);
assert(isequal(exactTimeoutBoundary.decisionCertificateNodeIds,1:4));

justBeforeTimeoutBoundary = model(1,4,38 - 1e-12,true,false);
assert(~justBeforeTimeoutBoundary.decided);
assert(justBeforeTimeoutBoundary.timedOut);
assert(~justBeforeTimeoutBoundary.canceled);
assert(strcmp(justBeforeTimeoutBoundary.outcome,'timed-out'));
assert(justBeforeTimeoutBoundary.requestResolutionTimeMs < 38);
assert(justBeforeTimeoutBoundary.observedVoteCount == 3);
assert(justBeforeTimeoutBoundary.votesStillNeeded == 1);
assert(isempty(justBeforeTimeoutBoundary.decisionCertificateNodeIds));
assert(all(~justBeforeTimeoutBoundary.decisionCertificateMask));
assert(isnan(justBeforeTimeoutBoundary.decisionTimeMs));
assert(isnan(justBeforeTimeoutBoundary.chosenValue));
assert(justBeforeTimeoutBoundary.potentialQuorumTimeMs == 38);
assert(justBeforeTimeoutBoundary.partialObservedVotesDoNotProveDecision);
assert(~justBeforeTimeoutBoundary.postResolutionProtocolProgressModeled);

zeroTimeoutWithoutQuorum = model(1,3,0,true,false);
assert(zeroTimeoutWithoutQuorum.timedOut);
assert(zeroTimeoutWithoutQuorum.requestResolutionTimeMs == 0);
assert(zeroTimeoutWithoutQuorum.observedVoteCount == 1);
assert(zeroTimeoutWithoutQuorum.votesStillNeeded == 2);
assert(isnan(zeroTimeoutWithoutQuorum.chosenValue));
assert(zeroTimeoutWithoutQuorum.potentialQuorumTimeMs == 26);
assert(zeroTimeoutWithoutQuorum.partialObservedVotesDoNotProveDecision);

timeoutAfterFourVotes = model(1,5,50,true,false);
assert(timeoutAfterFourVotes.timedOut);
assert(timeoutAfterFourVotes.quorumReachable);
assert(timeoutAfterFourVotes.potentialQuorumTimeMs == 62);
assert(timeoutAfterFourVotes.observedVoteCount == 4);
assert(timeoutAfterFourVotes.votesStillNeeded == 1);
assert(timeoutAfterFourVotes.timeoutMarginMs == -12);

nodeFiveUnavailable = model(1,3,100,false,false);
assert(nodeFiveUnavailable.decided);
assert(nodeFiveUnavailable.decisionTimeMs == 26);
assert(nodeFiveUnavailable.availableVoteCount == 4);
assert(isequal(nodeFiveUnavailable.offlineNodeIds,5));
assert(isnan(nodeFiveUnavailable.potentialVoteTimeMs(5)));
assert(nodeFiveUnavailable.quorumReachable);

unreachableQuorum = model(1,5,100,false,false);
assert(~unreachableQuorum.decided);
assert(unreachableQuorum.timedOut);
assert(~unreachableQuorum.quorumReachable);
assert(unreachableQuorum.availableVoteCount == 4);
assert(unreachableQuorum.observedVoteCount == 4);
assert(unreachableQuorum.votesStillNeeded == 1);
assert(isnan(unreachableQuorum.potentialQuorumTimeMs));
assert(isnan(unreachableQuorum.timeoutMarginMs));
assert(isnan(unreachableQuorum.chosenValue));

%% Cancellation, exact arbitration, no rollback, and recovery targets
canceledPending = model(1,3,100,true,true);
assert(~canceledPending.decided);
assert(~canceledPending.timedOut);
assert(canceledPending.canceled);
assert(strcmp(canceledPending.outcome,'canceled-pending'));
assert(canceledPending.requestResolutionTimeMs == 20);
assert(canceledPending.observedVoteCount == 2);
assert(canceledPending.votesStillNeeded == 1);
assert(isequal(canceledPending.voteObservedMask, ...
    [true true false false false]));
assert(isempty(canceledPending.decisionCertificateNodeIds));
assert(isnan(canceledPending.chosenValue));
assert(canceledPending.cancellationRequestModeled);
assert(canceledPending.cancellationTookEffectOnlyWhilePending);
assert(~canceledPending.cancellationCouldNotEraseObservedCertificate);
assert(canceledPending.cancellationClosesEvaluatorWindowOnly);
assert(~canceledPending.actualAsynchronousCancellationPerformed);
assert(canceledPending.potentialQuorumTimeMs == 26);
assert(canceledPending.partialObservedVotesDoNotProveDecision);
assert(~canceledPending.postResolutionProtocolProgressModeled);

decisionAtCancellationTie = model(0.75,3,100,true,true);
assert(isequal(decisionAtCancellationTie.potentialVoteTimeMs, ...
    [0 11 20 29 47]));
assert(decisionAtCancellationTie.decided);
assert(~decisionAtCancellationTie.canceled);
assert(decisionAtCancellationTie.decisionTimeMs == 20);
assert(decisionAtCancellationTie.decisionWonCancellationTie);
assert(decisionAtCancellationTie.cancellationCouldNotEraseObservedCertificate);
assert(isequal(decisionAtCancellationTie.decisionCertificateNodeIds,1:3));

cancellationTooLate = model(1,2,100,true,true);
assert(cancellationTooLate.decided);
assert(~cancellationTooLate.canceled);
assert(cancellationTooLate.decisionTimeMs == 14);
assert(~cancellationTooLate.decisionWonCancellationTie);
assert(cancellationTooLate.cancellationCouldNotEraseObservedCertificate);
assert(cancellationTooLate.chosenValue == 65);

cancellationTimeoutTie = model(1,3,20,true,true);
assert(~cancellationTimeoutTie.decided);
assert(~cancellationTimeoutTie.timedOut);
assert(cancellationTimeoutTie.canceled);
assert(strcmp(cancellationTimeoutTie.outcome,'canceled-pending'));
assert(cancellationTimeoutTie.requestResolutionTimeMs == 20);
assert(cancellationTimeoutTie.observedVoteCount == 2);
assert(cancellationTimeoutTie.potentialQuorumTimeMs == 26);
assert(cancellationTimeoutTie.cancellationHasTimeoutTiePrecedence);
assert(cancellationTimeoutTie.cancellationWonTimeoutTie);
assert(cancellationTimeoutTie.partialObservedVotesDoNotProveDecision);

% A timeout that resolves before the fixed 20 ms cancellation request must
% remain a timeout. The vote arriving exactly at 14 ms is still retained as
% evidence, but the later cancellation cannot reclassify the closed window.
timeoutBeforeCancellation = model(1,3,14,true,true);
assert(~timeoutBeforeCancellation.decided);
assert(timeoutBeforeCancellation.timedOut);
assert(~timeoutBeforeCancellation.canceled);
assert(strcmp(timeoutBeforeCancellation.outcome,'timed-out'));
assert(timeoutBeforeCancellation.requestResolutionTimeMs == 14);
assert(timeoutBeforeCancellation.observedVoteCount == 2);
assert(timeoutBeforeCancellation.votesStillNeeded == 1);
assert(timeoutBeforeCancellation.potentialQuorumTimeMs == 26);
assert(timeoutBeforeCancellation.cancellationRequestModeled);
assert(~timeoutBeforeCancellation.cancellationTookEffectOnlyWhilePending);
assert(~timeoutBeforeCancellation.cancellationWonTimeoutTie);
assert(timeoutBeforeCancellation.partialObservedVotesDoNotProveDecision);

cancellationBeforeUnreachableTimeout = model(1,5,100,false,true);
assert(cancellationBeforeUnreachableTimeout.canceled);
assert(~cancellationBeforeUnreachableTimeout.timedOut);
assert(cancellationBeforeUnreachableTimeout.observedVoteCount == 2);
assert(cancellationBeforeUnreachableTimeout.votesStillNeeded == 3);

recoveryAfterTimeout = model(1,3,100,true,false);
recoveryAfterCancellation = model(1,3,100,true,false);
recoveryAfterBrokenThreshold = model(1,3,100,true,false);
recoveryAfterAvailability = model(1,3,100,true,false);
assert(isequaln(recoveryAfterTimeout,baseline));
assert(isequaln(recoveryAfterCancellation,baseline));
assert(isequaln(recoveryAfterBrokenThreshold,baseline));
assert(isequaln(recoveryAfterAvailability,baseline));
assert(~baseline.rollbackModeled);
assert(~baseline.actualRollbackPerformed);
assert(baseline.observedVotesNotRolledBack);
assert(baseline.observedCertificateNotErasedByLateCancellation);
assert(~baseline.recoveryModeled);
assert(~baseline.retryModeled);
assert(baseline.freshEvaluationRequiredForRecoveryTarget);

%% Maximum resource bounds and explicit abstraction boundary
bounded = model(20,5,1e6,true,false);
assert(isequal(bounded.potentialVoteTimeMs,[0 242 482 722 1202]));
assert(bounded.decided);
assert(bounded.decisionTimeMs == 1202);
assert(bounded.observedVoteCount == 5);
assert(bounded.availableVoteCount == 5);
assert(bounded.potentialVoteSpreadMs == 1202);
assert(bounded.observationEventCount <= ...
    bounded.maxObservationEventCount);
assert(bounded.maxObservationEventCount == 7);
assert(bounded.maxWitnessCertificateMembershipCount == 10);
assert(bounded.maxCertificateMaskCount == 4);
assert(bounded.maxCertificateMaskMembershipSlots == 20);
assert(bounded.maxPotentialVoteTimeMs == 1202);
assert(bounded.maxResolutionTimeMs == 1e6);
assert(bounded.requestResolutionTimeMs <= bounded.maxResolutionTimeMs);
assert(all(bounded.potentialVoteTimeMs <= ...
    bounded.maxPotentialVoteTimeMs));
assert(bounded.calculationBounded);
assert(bounded.derivedTimeWithinBound);

assert(baseline.quorumEvidenceWinsExactTie);
assert(baseline.cancellationHasTimeoutTiePrecedence);
assert(~baseline.cancellationWonTimeoutTie);
assert(baseline.timeoutIsArithmeticClassification);
assert(~baseline.actualWallClockWaitPerformed);
assert(~baseline.actualAsynchronousCancellationPerformed);
assert(baseline.singleRoundQuorumEvidenceModeled);
assert(~baseline.fullConsensusProtocolModeled);
assert(~baseline.leaderElectionModeled);
assert(~baseline.logReplicationModeled);
assert(~baseline.valueApplicationModeled);
assert(~baseline.membershipChangeModeled);
assert(~baseline.partitionExecutionModeled);
assert(~baseline.competingProposalExecutionModeled);
assert(baseline.certificateGeometryOnly);
assert(baseline.fixedMembershipAssumed);
assert(baseline.crashStopAvailabilityOnly);
assert(~baseline.byzantineBehaviorModeled);
assert(~baseline.networkIoPerformed);
assert(~baseline.storageIoPerformed);
assert(~baseline.durableStateModeled);
assert(~baseline.backgroundWorkStarted);
assert(~baseline.physicalHardwareUsed);

%% Stable malformed-input failures and stateless recovery
assertThrows(@() model([],3,100,true,false), ...
    'P12:InvalidDelayScale');
assertThrows(@() model('1',3,100,true,false), ...
    'P12:InvalidDelayScale');
assertThrows(@() model([1 1],3,100,true,false), ...
    'P12:InvalidDelayScale');
assertThrows(@() model(1 + 1i,3,100,true,false), ...
    'P12:InvalidDelayScale');
assertThrows(@() model(nan,3,100,true,false), ...
    'P12:InvalidDelayScale');
assertThrows(@() model(inf,3,100,true,false), ...
    'P12:InvalidDelayScale');
assertThrows(@() model(-1,3,100,true,false), ...
    'P12:InvalidDelayScale');
assertThrows(@() model(20 + eps(20),3,100,true,false), ...
    'P12:InvalidDelayScale');

assertThrows(@() model(1,[],100,true,false), ...
    'P12:InvalidQuorumSize');
assertThrows(@() model(1,'3',100,true,false), ...
    'P12:InvalidQuorumSize');
assertThrows(@() model(1,[3 3],100,true,false), ...
    'P12:InvalidQuorumSize');
assertThrows(@() model(1,3 + 1i,100,true,false), ...
    'P12:InvalidQuorumSize');
assertThrows(@() model(1,nan,100,true,false), ...
    'P12:InvalidQuorumSize');
assertThrows(@() model(1,inf,100,true,false), ...
    'P12:InvalidQuorumSize');
assertThrows(@() model(1,0,100,true,false), ...
    'P12:InvalidQuorumSize');
assertThrows(@() model(1,2.5,100,true,false), ...
    'P12:InvalidQuorumSize');
assertThrows(@() model(1,6,100,true,false), ...
    'P12:InvalidQuorumSize');

assertThrows(@() model(1,3,[],true,false), ...
    'P12:InvalidDecisionTimeout');
assertThrows(@() model(1,3,'100',true,false), ...
    'P12:InvalidDecisionTimeout');
assertThrows(@() model(1,3,[100 100],true,false), ...
    'P12:InvalidDecisionTimeout');
assertThrows(@() model(1,3,100 + 1i,true,false), ...
    'P12:InvalidDecisionTimeout');
assertThrows(@() model(1,3,nan,true,false), ...
    'P12:InvalidDecisionTimeout');
assertThrows(@() model(1,3,inf,true,false), ...
    'P12:InvalidDecisionTimeout');
assertThrows(@() model(1,3,-1,true,false), ...
    'P12:InvalidDecisionTimeout');
assertThrows(@() model(1,3,1e6 + 1,true,false), ...
    'P12:InvalidDecisionTimeout');

assertThrows(@() model(1,3,100,[],false), ...
    'P12:InvalidNodeAvailability');
assertThrows(@() model(1,3,100,'true',false), ...
    'P12:InvalidNodeAvailability');
assertThrows(@() model(1,3,100,[1 1],false), ...
    'P12:InvalidNodeAvailability');
assertThrows(@() model(1,3,100,1 + 1i,false), ...
    'P12:InvalidNodeAvailability');
assertThrows(@() model(1,3,100,nan,false), ...
    'P12:InvalidNodeAvailability');
assertThrows(@() model(1,3,100,2,false), ...
    'P12:InvalidNodeAvailability');
assertThrows(@() model(1,3,100,-1,false), ...
    'P12:InvalidNodeAvailability');

assertThrows(@() model(1,3,100,true,[]), ...
    'P12:InvalidCancellationPolicy');
assertThrows(@() model(1,3,100,true,'false'), ...
    'P12:InvalidCancellationPolicy');
assertThrows(@() model(1,3,100,true,[0 0]), ...
    'P12:InvalidCancellationPolicy');
assertThrows(@() model(1,3,100,true,1 + 1i), ...
    'P12:InvalidCancellationPolicy');
assertThrows(@() model(1,3,100,true,nan), ...
    'P12:InvalidCancellationPolicy');
assertThrows(@() model(1,3,100,true,2), ...
    'P12:InvalidCancellationPolicy');
assertThrows(@() model(1,3,100,true,-1), ...
    'P12:InvalidCancellationPolicy');

recoveredAfterMalformed = model(1,3,100,true,false);
assert(isequaln(recoveredAfterMalformed,baseline));

fprintf(['P12 checks passed: quorum evidence, two sweeps, broken ' ...
    'intersection, timeout/cancellation, recovery targets, and bounds.\n']);
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
