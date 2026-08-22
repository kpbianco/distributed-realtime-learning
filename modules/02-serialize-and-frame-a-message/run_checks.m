function run_checks
%RUN_CHECKS Independent deterministic checks for the P02 protocol model.

baseline = model(4,1000,0);
expectedSamples = [-150 -50 50 150];
expectedPayload = uint8([42 18 52 255 106 255 206 0 50 0 150]);
expectedFrame = uint8([126 0 11 42 18 52 255 106 255 206 0 50 0 150 135]);
assert(isequal(baseline.samples,expectedSamples),'Deterministic samples changed.');
assert(isequal(baseline.payload,expectedPayload),'Big-endian serialization changed.');
assert(isequal(baseline.frame,expectedFrame),'Baseline frame bytes changed.');
assert(baseline.payloadBytes == 11 && baseline.actualFrameBytes == 15, ...
    'Baseline byte counts must be 11 payload and 15 frame bytes.');
assert(baseline.wireBits == 120 && abs(baseline.serializationTimeMs - 0.120) < 1e-12, ...
    'Baseline must occupy 120 bits and 0.120 ms at 1000 kb/s.');
assert(abs(baseline.framingEfficiency - 11/15) < 1e-12,'Efficiency must be P/F.');
assert(baseline.checksum == 135 && baseline.senderChecksumResidue == 0, ...
    'Baseline checksum residue must be zero modulo 256.');
assert(baseline.receiverAccepted && baseline.checksumValid && baseline.lengthMatches, ...
    'The honest baseline frame must be accepted.');
assert(baseline.decodedMessageType == 42 && baseline.decodedSequence == hex2dec('1234'), ...
    'Message type or sequence did not round-trip.');
assert(isequal(baseline.decodedSamples,expectedSamples),'Signed samples did not round-trip.');

repeated = model(4,1000,0);
assert(isequal(repeated.frame,baseline.frame) && ...
    repeated.serializationTimeMs == baseline.serializationTimeMs, ...
    'Identical inputs must produce identical output.');

typed = model(uint8(4),uint16(1000),int8(0));
assert(isequal(typed.frame,baseline.frame) && typed.serializationTimeMs == baseline.serializationTimeMs, ...
    'Accepted integer-class scalars must normalize to the baseline arithmetic.');

zero = model(0,1000,0);
assert(isequal(zero.payload,uint8([42 18 52])),'Zero-sample payload retains type and sequence.');
assert(zero.payloadBytes == 3 && zero.actualFrameBytes == 7 && zero.wireBits == 56, ...
    'Zero-sample limiting byte counts changed.');
assert(zero.checksum == 141 && zero.receiverAccepted,'Zero-sample frame should remain valid.');

bounded = model(64,1000,0);
assert(bounded.payloadBytes == 131 && bounded.actualFrameBytes == 135, ...
    'Maximum bounded frame must be 131 payload and 135 total bytes.');
assert(bounded.wireBits == 1080 && abs(bounded.serializationTimeMs - 1.080) < 1e-12, ...
    'Maximum bounded frame timing changed.');
assert(bounded.samples(end) == 6150 && bounded.checksum == 63 && bounded.receiverAccepted, ...
    'Maximum bounded payload must serialize and decode exactly.');
typedBounded = model(uint8(64),uint16(1000),int16(0));
assert(isequal(typedBounded.frame,bounded.frame) && typedBounded.receiverAccepted, ...
    'Integer-class inputs must not saturate maximum bounded lengths.');

sampleCounts = [0 1 4 16];
expectedFrames = [7 9 15 39];
expectedSampleTimes = [0.056 0.072 0.120 0.312];
actualFrames = zeros(size(sampleCounts));
actualSampleTimes = zeros(size(sampleCounts));
for index = 1:numel(sampleCounts)
    swept = model(sampleCounts(index),1000,0);
    actualFrames(index) = swept.actualFrameBytes;
    actualSampleTimes(index) = swept.serializationTimeMs;
end
assert(isequal(actualFrames,expectedFrames),'Sample-count sweep frame sizes changed.');
assert(max(abs(actualSampleTimes - expectedSampleTimes)) < 1e-12, ...
    'Sample-count sweep times changed.');

linkRates = [125 1000 10000];
expectedRateTimes = [0.960 0.120 0.012];
actualRateTimes = zeros(size(linkRates));
actualRateFrames = zeros(size(linkRates));
actualRateEfficiency = zeros(size(linkRates));
for index = 1:numel(linkRates)
    swept = model(4,linkRates(index),0);
    actualRateTimes(index) = swept.serializationTimeMs;
    actualRateFrames(index) = swept.actualFrameBytes;
    actualRateEfficiency(index) = swept.framingEfficiency;
end
assert(max(abs(actualRateTimes - expectedRateTimes)) < 1e-12,'Link-rate sweep times changed.');
assert(all(actualRateFrames == 15),'Link rate must not change frame bytes.');
assert(max(abs(actualRateEfficiency - 11/15)) < 1e-12, ...
    'Link rate must not change framing efficiency.');

broken = model(4,1000,2);
assert(broken.declaredPayloadBytes == 13 && broken.expectedFrameBytes == 17 && broken.schemaValid, ...
    'Broken case must declare one structurally possible sample that was not sent.');
assert(broken.actualFrameBytes == 15 && broken.missingBytes == 2 && broken.extraBytes == 0, ...
    'Broken case must expose exactly two missing bytes.');
assert(~broken.checksumEvaluated && ~broken.checksumValid && ~broken.receiverAccepted, ...
    'An incomplete frame must not be checksum-valid or accepted.');
assert(broken.timeoutRequired && broken.receiverState == "waiting-for-bytes", ...
    'Incomplete framing must expose the bounded timeout state.');

invalidSchema = model(4,1000,3);
assert(~invalidSchema.schemaValid && ~invalidSchema.timeoutRequired && ...
    invalidSchema.receiverState == "rejected-schema", ...
    'An even declared payload length must reject immediately as invalid schema.');

shortDeclaration = model(4,1000,-2);
assert(shortDeclaration.schemaValid && shortDeclaration.extraBytes == 2 && ...
    shortDeclaration.receiverState == "rejected-extra-bytes" && ...
    ~shortDeclaration.receiverAccepted, ...
    'A structurally valid under-declaration must reject two trailing bytes.');

overLimit = model(4,1000,121);
assert(overLimit.declaredPayloadBytes == 132 && ~overLimit.declaredLengthWithinPolicy, ...
    'A declaration above the 131-byte protocol limit must violate receiver policy.');
assert(~overLimit.timeoutRequired && ~overLimit.checksumEvaluated && ~overLimit.receiverAccepted, ...
    'An over-policy declaration must reject immediately without waiting or checksum evaluation.');
assert(overLimit.receiverState == "rejected-length-limit", ...
    'An over-policy declaration must report the length-limit failure.');

corrupted = baseline.frame;
corrupted(8) = bitxor(corrupted(8),uint8(1));
assert(mod(sum(double(corrupted(2:end))),256) ~= 0, ...
    'A one-bit payload change must disturb this frame checksum.');

assertThrows(@() model(65,1000,0),'P02:InvalidSampleCount');
assertThrows(@() model(-1,1000,0),'P02:InvalidSampleCount');
assertThrows(@() model(1.5,1000,0),'P02:InvalidSampleCount');
assertThrows(@() model(NaN,1000,0),'P02:InvalidSampleCount');
assertThrows(@() model([1 2],1000,0),'P02:InvalidSampleCount');
assertThrows(@() model(4,0,0),'P02:InvalidLinkRate');
assertThrows(@() model(4,Inf,0),'P02:InvalidLinkRate');
assertThrows(@() model(4,[1000 2000],0),'P02:InvalidLinkRate');
assertThrows(@() model(4,1e6 + 1,0),'P02:InvalidLinkRate');
assertThrows(@() model(4,1000,0.5),'P02:InvalidDeclaredLengthDelta');
assertThrows(@() model(4,1000,Inf),'P02:InvalidDeclaredLengthDelta');
assertThrows(@() model(0,1000,-4),'P02:DeclaredLengthOutOfRange');
assertThrows(@() model(0,1000,65533),'P02:DeclaredLengthOutOfRange');

recovered = model(4,1000,0);
assert(isequal(recovered.frame,baseline.frame) && recovered.receiverAccepted, ...
    'A valid call after malformed inputs must recover with no retained state.');

disp('P02 checks passed: serialization, framing, sweeps, malformed lengths, bounds, and recovery.');
end

function assertThrows(action,expectedIdentifier)
didThrow = false;
try
    action();
catch exception
    didThrow = true;
    assert(strcmp(exception.identifier,expectedIdentifier), ...
        'Expected %s but received %s.',expectedIdentifier,exception.identifier);
end
assert(didThrow,'Expected error %s was not thrown.',expectedIdentifier);
end
