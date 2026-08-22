%% P02 - Serialize and Frame a Message
close all; clc;

%% Read the protocol before looking at syntax
disp('What inputs, observable effects, and failure modes matter when you serialize and Frame a Message?');
disp(['Serialization maps type, sequence, and signed samples to agreed big-endian bytes. ' ...
    'Framing adds a sync byte, length, and checksum so a receiver knows what to wait for and verify.']);
disp('Prediction: which changes frame size -- sample count, link rate, or both?');

%% Visualize the deterministic baseline
baseline = model(4,1000,0);
fprintf('Baseline: %d payload bytes, %d frame bytes, %d wire bits\n', ...
    baseline.payloadBytes,baseline.actualFrameBytes,baseline.wireBits);
fprintf('At %.0f kb/s: %.3f ms serialization time, %.1f%% payload efficiency\n', ...
    baseline.linkRateKbps,baseline.serializationTimeMs,100 * baseline.framingEfficiency);
fprintf('Checksum 0x%02X, receiver state: %s\n', ...
    baseline.checksum,char(baseline.receiverState));

figure('Name','P02 baseline frame bytes');
stem(0:baseline.actualFrameBytes-1,double(baseline.frame),'filled','LineWidth',1.1);
grid on; ylim([-5 260]);
xlabel('Frame byte index (zero-based)'); ylabel('Byte value (decimal, 0-255)');
title('Baseline: explicit bytes placed on the link');

figure('Name','P02 baseline byte budget');
bar([baseline.payloadBytes baseline.protocolOverheadBytes],0.6);
set(gca,'XTick',1:2,'XTickLabel',{'Serialized payload','Framing overhead'});
grid on; ylabel('Bytes');
title('Baseline: payload versus sync, length, and checksum');

%% Sweep 1 - move the sample-count lever and inspect the changed view
sampleCounts = [0 1 4 16];
sampleSweepTimes = zeros(size(sampleCounts));
sampleSweepFrames = zeros(size(sampleCounts));
for index = 1:numel(sampleCounts)
    swept = model(sampleCounts(index),1000,0);
    sampleSweepTimes(index) = swept.serializationTimeMs;
    sampleSweepFrames(index) = swept.actualFrameBytes;
end
figure('Name','P02 sample-count frame-size sweep');
plot(sampleCounts,sampleSweepFrames,'-o','LineWidth',1.4,'MarkerFaceColor',[0.2 0.5 0.8]);
grid on; xlabel('Signed 16-bit samples per message (count)'); ylabel('Frame bytes');
title('Sweep 1 changed view: each sample adds two frame bytes');

figure('Name','P02 sample-count sweep');
plot(sampleCounts,sampleSweepTimes,'-o','LineWidth',1.4,'MarkerFaceColor',[0.2 0.5 0.8]);
grid on; xlabel('Signed 16-bit samples per message (count)');
ylabel('Serialization time at 1000 kb/s (ms)');
title('Sweep 1: more serialized fields occupy the link longer');
disp('Mechanism: every added sample contributes 16 bits, so frame size and wire time rise together.');

%% Sweep 2 - reset the frame, move only the link-rate lever
linkRatesKbps = [125 1000 10000];
rateSweepTimes = zeros(size(linkRatesKbps));
rateSweepFrames = zeros(size(linkRatesKbps));
for index = 1:numel(linkRatesKbps)
    swept = model(4,linkRatesKbps(index),0);
    rateSweepTimes(index) = swept.serializationTimeMs;
    rateSweepFrames(index) = swept.actualFrameBytes;
end
figure('Name','P02 link-rate frame-size sweep');
semilogx(linkRatesKbps,rateSweepFrames,'-o','LineWidth',1.4,'MarkerFaceColor',[0.8 0.4 0.2]);
grid on; xlabel('Link rate (kb/s, logarithmic scale)'); ylabel('Frame bytes');
title('Sweep 2 invariant view: rate does not change the frame');

figure('Name','P02 link-rate sweep');
semilogx(linkRatesKbps,rateSweepTimes,'-o','LineWidth',1.4,'MarkerFaceColor',[0.8 0.4 0.2]);
grid on; xlabel('Link rate (kb/s, logarithmic scale)'); ylabel('Serialization time (ms)');
title('Sweep 2: rate changes time, not frame bytes');
disp('Mechanism: T = 8F/R; increasing R shortens occupancy while the same F bytes remain on the wire.');

%% Deliberately broken case - declare two bytes that were never sent
broken = model(4,1000,2);
figure('Name','P02 broken declared length');
bar([broken.actualFrameBytes broken.expectedFrameBytes],0.6);
set(gca,'XTick',1:2,'XTickLabel',{'Bytes received','Bytes receiver expects'});
grid on; ylabel('Frame bytes');
title('Broken: false length leaves the receiver waiting');
fprintf(['Broken length: declared payload %d bytes, received frame %d of %d bytes; ' ...
    'missing %d, state %s, timeout required %d\n'], ...
    broken.declaredPayloadBytes,broken.actualFrameBytes,broken.expectedFrameBytes, ...
    broken.missingBytes,char(broken.receiverState),broken.timeoutRequired);
disp(['Mechanism: the receiver trusts the length prefix, so it cannot yet treat the last received byte ' ...
    'as the checksum. A bounded implementation waits only until its timeout or frame-size limit.']);

assert(isequal(baseline.samples,[-150 -50 50 150]));
assert(baseline.actualFrameBytes == 15 && abs(baseline.serializationTimeMs - 0.120) < 1e-12);
assert(all(rateSweepFrames == baseline.actualFrameBytes));
assert(~broken.receiverAccepted && broken.timeoutRequired && broken.missingBytes == 2);
