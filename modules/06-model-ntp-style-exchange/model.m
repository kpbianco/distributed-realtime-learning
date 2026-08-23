function out = model(clientSendTimeMs,clockOffsetMs,forwardDelayMs,reverseDelayMs,serverProcessingMs)
%MODEL Deterministic four-timestamp exchange for the P06 lesson.
% clockOffsetMs is server clock minus client clock. Interpreting the
% four-timestamp offset estimate as true offset requires path symmetry.

if nargin < 1
    clientSendTimeMs = 100;
end
if nargin < 2
    clockOffsetMs = 7;
end
if nargin < 3
    forwardDelayMs = 4;
end
if nargin < 4
    reverseDelayMs = 4;
end
if nargin < 5
    serverProcessingMs = 2;
end

maxTimeMagnitudeMs = 1e6;
maxTimestampCount = 4;
maxDerivedTimestampMagnitudeMs = 4 * maxTimeMagnitudeMs;

if ~(isnumeric(clientSendTimeMs) && isreal(clientSendTimeMs) && ...
        isscalar(clientSendTimeMs) && isfinite(clientSendTimeMs) && ...
        clientSendTimeMs >= -maxTimeMagnitudeMs && ...
        clientSendTimeMs <= maxTimeMagnitudeMs)
    error('P06:InvalidClientSendTime', ...
        'clientSendTimeMs must be a finite scalar from %.0f through %.0f ms.', ...
        -maxTimeMagnitudeMs,maxTimeMagnitudeMs);
end
if ~(isnumeric(clockOffsetMs) && isreal(clockOffsetMs) && ...
        isscalar(clockOffsetMs) && isfinite(clockOffsetMs) && ...
        clockOffsetMs >= -maxTimeMagnitudeMs && ...
        clockOffsetMs <= maxTimeMagnitudeMs)
    error('P06:InvalidClockOffset', ...
        'clockOffsetMs must be a finite scalar from %.0f through %.0f ms.', ...
        -maxTimeMagnitudeMs,maxTimeMagnitudeMs);
end
if ~(isnumeric(forwardDelayMs) && isreal(forwardDelayMs) && ...
        isscalar(forwardDelayMs) && isfinite(forwardDelayMs) && ...
        forwardDelayMs >= 0 && forwardDelayMs <= maxTimeMagnitudeMs)
    error('P06:InvalidForwardDelay', ...
        'forwardDelayMs must be a finite scalar from 0 through %.0f ms.', ...
        maxTimeMagnitudeMs);
end
if ~(isnumeric(reverseDelayMs) && isreal(reverseDelayMs) && ...
        isscalar(reverseDelayMs) && isfinite(reverseDelayMs) && ...
        reverseDelayMs >= 0 && reverseDelayMs <= maxTimeMagnitudeMs)
    error('P06:InvalidReverseDelay', ...
        'reverseDelayMs must be a finite scalar from 0 through %.0f ms.', ...
        maxTimeMagnitudeMs);
end
if ~(isnumeric(serverProcessingMs) && isreal(serverProcessingMs) && ...
        isscalar(serverProcessingMs) && isfinite(serverProcessingMs) && ...
        serverProcessingMs >= 0 && ...
        serverProcessingMs <= maxTimeMagnitudeMs)
    error('P06:InvalidServerProcessing', ...
        'serverProcessingMs must be a finite scalar from 0 through %.0f ms.', ...
        maxTimeMagnitudeMs);
end

clientSendTimeMs = double(clientSendTimeMs);
clockOffsetMs = double(clockOffsetMs);
forwardDelayMs = double(forwardDelayMs);
reverseDelayMs = double(reverseDelayMs);
serverProcessingMs = double(serverProcessingMs);

% Truth time is available only because this is a teaching model. The client
% clock is the reference; the server clock reads truth time plus theta.
trueClientTransmitTimeMs = clientSendTimeMs;
trueServerReceiveTimeMs = clientSendTimeMs + forwardDelayMs;
trueServerTransmitTimeMs = trueServerReceiveTimeMs + serverProcessingMs;
trueClientReceiveTimeMs = trueServerTransmitTimeMs + reverseDelayMs;
trueEventTimeMs = [trueClientTransmitTimeMs;trueServerReceiveTimeMs; ...
    trueServerTransmitTimeMs;trueClientReceiveTimeMs];
trueEventElapsedMs = trueEventTimeMs - clientSendTimeMs;

t1ClientTransmitMs = trueClientTransmitTimeMs;
t2ServerReceiveMs = trueServerReceiveTimeMs + clockOffsetMs;
t3ServerTransmitMs = trueServerTransmitTimeMs + clockOffsetMs;
t4ClientReceiveMs = trueClientReceiveTimeMs;
timestampObservationMs = [t1ClientTransmitMs;t2ServerReceiveMs; ...
    t3ServerTransmitMs;t4ClientReceiveMs];

forwardOffsetTermMs = t2ServerReceiveMs - t1ClientTransmitMs;
reverseOffsetTermMs = t3ServerTransmitMs - t4ClientReceiveMs;
clientElapsedMs = t4ClientReceiveMs - t1ClientTransmitMs;
serverResidenceMs = t3ServerTransmitMs - t2ServerReceiveMs;

estimatedClockOffsetMs = ...
    (forwardOffsetTermMs + reverseOffsetTermMs) / 2;
rawEstimatedNetworkRoundTripDelayMs = clientElapsedMs - serverResidenceMs;
trueNetworkRoundTripDelayMs = forwardDelayMs + reverseDelayMs;
trueMeanOneWayDelayMs = trueNetworkRoundTripDelayMs / 2;
pathAsymmetryMs = forwardDelayMs - reverseDelayMs;

timeScaleMs = max([1;abs(timestampObservationMs);abs(clockOffsetMs); ...
    forwardDelayMs;reverseDelayMs;serverProcessingMs]);
comparisonToleranceMs = 64 * eps(timeScaleMs);
roundTripNormalizationApplied = rawEstimatedNetworkRoundTripDelayMs < 0;
estimatedNetworkRoundTripDelayMs = ...
    max(rawEstimatedNetworkRoundTripDelayMs,0);
estimatedSymmetricOneWayDelayMs = estimatedNetworkRoundTripDelayMs / 2;
clockOffsetErrorMs = estimatedClockOffsetMs - clockOffsetMs;
forwardDelayInferenceErrorMs = estimatedSymmetricOneWayDelayMs - forwardDelayMs;
reverseDelayInferenceErrorMs = estimatedSymmetricOneWayDelayMs - reverseDelayMs;

expectedOffsetEstimateMs = clockOffsetMs + pathAsymmetryMs / 2;
offsetIdentityResidualMs = estimatedClockOffsetMs - expectedOffsetEstimateMs;
roundTripIdentityResidualMs = estimatedNetworkRoundTripDelayMs - ...
    trueNetworkRoundTripDelayMs;
rawRoundTripIdentityResidualMs = rawEstimatedNetworkRoundTripDelayMs - ...
    trueNetworkRoundTripDelayMs;
responseIdentityResidualMs = clientElapsedMs - ...
    (forwardDelayMs + serverProcessingMs + reverseDelayMs);
processingCancellationResidualMs = estimatedNetworkRoundTripDelayMs - ...
    trueNetworkRoundTripDelayMs;
rawRoundTripWithinNumericalTolerance = ...
    rawEstimatedNetworkRoundTripDelayMs >= -comparisonToleranceMs;
pathSymmetrySatisfiedInTruth = forwardDelayMs == reverseDelayMs;
clockOffsetUnbiasedInTruth = pathSymmetrySatisfiedInTruth;
zeroNetworkRoundTripLimitInTruth = ...
    forwardDelayMs == 0 && reverseDelayMs == 0;
pathSymmetryGenerallyObservableFromOneExchange = false;
timestampObservationsGenerallyUniqueToPhysicalTruth = false;
if pathSymmetrySatisfiedInTruth
    exchangeState = 'symmetric-unbiased';
else
    exchangeState = 'asymmetric-offset-bias';
end

out = struct();
out.clientSendTimeMs = clientSendTimeMs;
out.clockOffsetMs = clockOffsetMs;
out.forwardDelayMs = forwardDelayMs;
out.reverseDelayMs = reverseDelayMs;
out.serverProcessingMs = serverProcessingMs;
out.trueClientTransmitTimeMs = trueClientTransmitTimeMs;
out.trueServerReceiveTimeMs = trueServerReceiveTimeMs;
out.trueServerTransmitTimeMs = trueServerTransmitTimeMs;
out.trueClientReceiveTimeMs = trueClientReceiveTimeMs;
out.trueEventTimeMs = trueEventTimeMs;
out.trueEventElapsedMs = trueEventElapsedMs;
out.t1ClientTransmitMs = t1ClientTransmitMs;
out.t2ServerReceiveMs = t2ServerReceiveMs;
out.t3ServerTransmitMs = t3ServerTransmitMs;
out.t4ClientReceiveMs = t4ClientReceiveMs;
out.timestampObservationMs = timestampObservationMs;
out.forwardOffsetTermMs = forwardOffsetTermMs;
out.reverseOffsetTermMs = reverseOffsetTermMs;
out.clientElapsedMs = clientElapsedMs;
out.serverResidenceMs = serverResidenceMs;
out.estimatedClockOffsetMs = estimatedClockOffsetMs;
out.rawEstimatedNetworkRoundTripDelayMs = ...
    rawEstimatedNetworkRoundTripDelayMs;
out.estimatedNetworkRoundTripDelayMs = estimatedNetworkRoundTripDelayMs;
out.estimatedSymmetricOneWayDelayMs = estimatedSymmetricOneWayDelayMs;
out.trueNetworkRoundTripDelayMs = trueNetworkRoundTripDelayMs;
out.trueMeanOneWayDelayMs = trueMeanOneWayDelayMs;
out.pathAsymmetryMs = pathAsymmetryMs;
out.clockOffsetErrorMs = clockOffsetErrorMs;
out.forwardDelayInferenceErrorMs = forwardDelayInferenceErrorMs;
out.reverseDelayInferenceErrorMs = reverseDelayInferenceErrorMs;
out.expectedOffsetEstimateMs = expectedOffsetEstimateMs;
out.offsetIdentityResidualMs = offsetIdentityResidualMs;
out.roundTripIdentityResidualMs = roundTripIdentityResidualMs;
out.rawRoundTripIdentityResidualMs = rawRoundTripIdentityResidualMs;
out.responseIdentityResidualMs = responseIdentityResidualMs;
out.processingCancellationResidualMs = processingCancellationResidualMs;
out.roundTripNormalizationApplied = roundTripNormalizationApplied;
out.rawRoundTripWithinNumericalTolerance = ...
    rawRoundTripWithinNumericalTolerance;
out.pathSymmetrySatisfiedInTruth = pathSymmetrySatisfiedInTruth;
out.clockOffsetUnbiasedInTruth = clockOffsetUnbiasedInTruth;
out.exchangeState = exchangeState;
out.pathSymmetryRequiredForUnbiasedOffset = true;
out.pathSymmetryGenerallyObservableFromOneExchange = ...
    pathSymmetryGenerallyObservableFromOneExchange;
out.timestampObservationsGenerallyUniqueToPhysicalTruth = ...
    timestampObservationsGenerallyUniqueToPhysicalTruth;
out.zeroNetworkRoundTripLimitInTruth = zeroNetworkRoundTripLimitInTruth;
out.truthClassificationUsesExactInputs = true;
out.serverProcessingRemovedFromNetworkRoundTrip = true;
out.truthAvailableForTeachingOnly = true;
out.clientClockIsReference = true;
out.serverClockRateMatchesClient = true;
out.twoWayExchangeModeled = true;
out.fullNtpProtocolModeled = false;
out.multipleExchangesModeled = false;
out.clockFilterModeled = false;
out.clockSkewModeled = false;
out.timestampNoiseModeled = false;
out.packetLossModeled = false;
out.hardwareTimestampingModeled = false;
out.networkIoPerformed = false;
out.clockAdjustmentPerformed = false;
out.timeoutModeled = false;
out.cancellationModeled = false;
out.actualWaitPerformed = false;
out.timestampCount = numel(timestampObservationMs);
out.maxTimestampCount = maxTimestampCount;
out.maxTimeMagnitudeMs = maxTimeMagnitudeMs;
out.maxDerivedTimestampMagnitudeMs = maxDerivedTimestampMagnitudeMs;
out.comparisonToleranceMs = comparisonToleranceMs;
out.calculationBounded = true;
end
