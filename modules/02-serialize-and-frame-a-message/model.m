function out = model(sampleCount,linkRateKbps,declaredLengthDelta)
%MODEL Serialize a typed message, frame it, and evaluate receiver state.
%   The byte order and checksum arithmetic are explicit so the protocol is
%   observable rather than hidden behind a serialization toolbox.

if nargin < 1
    sampleCount = 4;
end
if nargin < 2
    linkRateKbps = 1000;
end
if nargin < 3
    declaredLengthDelta = 0;
end

if ~(isnumeric(sampleCount) && isreal(sampleCount) && isscalar(sampleCount) && ...
        isfinite(sampleCount) && sampleCount == fix(sampleCount) && ...
        sampleCount >= 0 && sampleCount <= 64)
    error('P02:InvalidSampleCount', ...
        'sampleCount must be a finite integer from 0 through 64.');
end
if ~(isnumeric(linkRateKbps) && isreal(linkRateKbps) && isscalar(linkRateKbps) && ...
        isfinite(linkRateKbps) && linkRateKbps >= 1 && linkRateKbps <= 1e6)
    error('P02:InvalidLinkRate', ...
        'linkRateKbps must be finite and in the range 1 through 1e6 kb/s.');
end
if ~(isnumeric(declaredLengthDelta) && isreal(declaredLengthDelta) && ...
        isscalar(declaredLengthDelta) && isfinite(declaredLengthDelta) && ...
        declaredLengthDelta == fix(declaredLengthDelta))
    error('P02:InvalidDeclaredLengthDelta', ...
        'declaredLengthDelta must be a finite integer.');
end

% Normalize accepted numeric classes before arithmetic. MATLAB preserves
% integer classes in mixed arithmetic, which could otherwise saturate a
% valid length or rate calculation.
sampleCount = double(sampleCount);
linkRateKbps = double(linkRateKbps);
declaredLengthDelta = double(declaredLengthDelta);

messageType = uint8(42);
sequence = uint16(hex2dec('1234'));
samples = 100 * (1:sampleCount) - 250;
payloadBytes = 3 + 2 * sampleCount;
maxPayloadBytes = 3 + 2 * 64;
declaredPayloadBytes = payloadBytes + declaredLengthDelta;
if declaredPayloadBytes < 0 || declaredPayloadBytes > 65535
    error('P02:DeclaredLengthOutOfRange', ...
        'The declared payload length must fit an unsigned 16-bit field.');
end

payload = zeros(1,payloadBytes,'uint8');
payload(1) = messageType;
payload(2) = uint8(floor(double(sequence) / 256));
payload(3) = uint8(mod(double(sequence),256));
for index = 1:sampleCount
    encoded = mod(samples(index),65536);
    payload(2 + 2 * index) = uint8(floor(encoded / 256));
    payload(3 + 2 * index) = uint8(mod(encoded,256));
end

syncByte = uint8(126);
lengthHigh = uint8(floor(declaredPayloadBytes / 256));
lengthLow = uint8(mod(declaredPayloadBytes,256));
frameWithoutChecksum = uint8([syncByte lengthHigh lengthLow payload]);
checksum = uint8(mod(-sum(double(frameWithoutChecksum(2:end))),256));
frame = uint8([frameWithoutChecksum checksum]);

actualFrameBytes = numel(frame);
expectedFrameBytes = declaredPayloadBytes + 4;
wireBits = 8 * actualFrameBytes;
serializationTimeMs = wireBits / linkRateKbps;
framingEfficiency = payloadBytes / actualFrameBytes;
missingBytes = max(expectedFrameBytes - actualFrameBytes,0);
extraBytes = max(actualFrameBytes - expectedFrameBytes,0);
declaredLengthWithinPolicy = declaredPayloadBytes <= maxPayloadBytes;
lengthMatches = declaredPayloadBytes == payloadBytes;
schemaValid = declaredPayloadBytes >= 3 && mod(declaredPayloadBytes - 3,2) == 0;

checksumEvaluated = declaredLengthWithinPolicy && schemaValid && ...
    actualFrameBytes >= expectedFrameBytes;
receiverChecksumResidue = NaN;
checksumValid = false;
if checksumEvaluated
    receiverChecksumResidue = mod(sum(double(frame(2:expectedFrameBytes))),256);
    checksumValid = receiverChecksumResidue == 0;
end

receiverAccepted = frame(1) == syncByte && declaredLengthWithinPolicy && ...
    lengthMatches && schemaValid && checksumValid;
timeoutRequired = declaredLengthWithinPolicy && schemaValid && missingBytes > 0;
if ~declaredLengthWithinPolicy
    receiverState = "rejected-length-limit";
elseif ~schemaValid
    receiverState = "rejected-schema";
elseif timeoutRequired
    receiverState = "waiting-for-bytes";
elseif extraBytes > 0
    receiverState = "rejected-extra-bytes";
elseif ~checksumValid
    receiverState = "rejected-checksum";
else
    receiverState = "accepted";
end

decodedMessageType = NaN;
decodedSequence = NaN;
decodedSamples = zeros(1,0);
if receiverAccepted
    receivedPayload = frame(4:3 + declaredPayloadBytes);
    decodedMessageType = double(receivedPayload(1));
    decodedSequence = 256 * double(receivedPayload(2)) + double(receivedPayload(3));
    decodedSamples = zeros(1,(declaredPayloadBytes - 3) / 2);
    for index = 1:numel(decodedSamples)
        encoded = 256 * double(receivedPayload(2 + 2 * index)) + ...
            double(receivedPayload(3 + 2 * index));
        if encoded >= 32768
            encoded = encoded - 65536;
        end
        decodedSamples(index) = encoded;
    end
end

out = struct( ...
    'sampleCount',sampleCount, ...
    'linkRateKbps',linkRateKbps, ...
    'declaredLengthDelta',declaredLengthDelta, ...
    'messageType',double(messageType), ...
    'sequence',double(sequence), ...
    'samples',samples, ...
    'payload',payload, ...
    'frame',frame, ...
    'payloadBytes',payloadBytes, ...
    'maxPayloadBytes',maxPayloadBytes, ...
    'declaredPayloadBytes',declaredPayloadBytes, ...
    'protocolOverheadBytes',actualFrameBytes - payloadBytes, ...
    'actualFrameBytes',actualFrameBytes, ...
    'expectedFrameBytes',expectedFrameBytes, ...
    'wireBits',wireBits, ...
    'serializationTimeMs',serializationTimeMs, ...
    'framingEfficiency',framingEfficiency, ...
    'checksum',double(checksum), ...
    'senderChecksumResidue',mod(sum(double(frame(2:end))),256), ...
    'checksumEvaluated',checksumEvaluated, ...
    'receiverChecksumResidue',receiverChecksumResidue, ...
    'checksumValid',checksumValid, ...
    'declaredLengthWithinPolicy',declaredLengthWithinPolicy, ...
    'lengthMatches',lengthMatches, ...
    'schemaValid',schemaValid, ...
    'missingBytes',missingBytes, ...
    'extraBytes',extraBytes, ...
    'timeoutRequired',timeoutRequired, ...
    'receiverState',receiverState, ...
    'receiverAccepted',receiverAccepted, ...
    'decodedMessageType',decodedMessageType, ...
    'decodedSequence',decodedSequence, ...
    'decodedSamples',decodedSamples);
end
