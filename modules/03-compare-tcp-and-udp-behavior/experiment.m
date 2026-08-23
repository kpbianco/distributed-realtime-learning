%% P03 - Compare TCP and UDP Behavior
close all; clc;

%% Read the service model before looking at syntax
disp('What inputs, observable effects, and failure modes matter when you compare TCP and UDP Behavior?');
disp(['One P02 frame is the application record. UDP exposes each available datagram immediately; ' ...
    'TCP exposes only a contiguous byte-stream prefix after loss recovery.']);
disp('Prediction: after record 3 is lost, which transport lets record 4 reach the application first?');

%% Visualize the deterministic baseline
baseline = model(6,200,20,3,1000,800);
fprintf(['Baseline: %d records, lost record %d, %.2f ms no-loss service, ' ...
    '%.0f ms TCP timeout\n'],baseline.messageCount,baseline.lostMessageIndex, ...
    baseline.serviceDelayMs,baseline.retransmissionTimeoutMs);
fprintf(['TCP: %d/%d eventual, %d/%d on time, %d retransmission, ' ...
    'maximum head-of-line wait %.0f ms\n'],baseline.tcpDeliveredCount,baseline.messageCount, ...
    baseline.tcpOnTimeCount,baseline.messageCount,baseline.tcpRetransmissionCount, ...
    baseline.maxTcpHeadOfLineDelayMs);
fprintf('UDP: %d/%d eventual, %d/%d on time, %d visible gap\n', ...
    baseline.udpDeliveredCount,baseline.messageCount,baseline.udpOnTimeCount, ...
    baseline.messageCount,baseline.udpLostCount);

figure('Name','P03 baseline transport and application arrival');
plot(baseline.recordIndex,baseline.tcpNetworkArrivalTimeMs,'o--','LineWidth',1.2, ...
    'DisplayName','TCP byte range reaches receiver'); hold on;
plot(baseline.recordIndex,baseline.tcpApplicationDeliveryTimeMs,'s-','LineWidth',1.4, ...
    'DisplayName','TCP contiguous bytes reach application');
plot(baseline.recordIndex,baseline.udpDeliveryTimeMs,'d-','LineWidth',1.4, ...
    'DisplayName','UDP datagram reaches application');
scatter(baseline.recordIndex(baseline.lostMask),baseline.baseArrivalTimeMs(baseline.lostMask), ...
    80,'x','LineWidth',1.8,'DisplayName','Lost first attempt');
grid on; xlabel('P02 application record index'); ylabel('Time from first send (ms)');
title('Baseline changed view: UDP leaves a hole; TCP waits for a contiguous prefix');
legend('Location','best');

figure('Name','P03 baseline record age');
plot(baseline.recordIndex,baseline.tcpLatencyMs,'s-','LineWidth',1.4, ...
    'DisplayName','TCP application age'); hold on;
plot(baseline.recordIndex,baseline.udpLatencyMs,'d-','LineWidth',1.4, ...
    'DisplayName','UDP application age');
yline(baseline.deadlineMs,':','Application deadline','LineWidth',1.2);
scatter(baseline.recordIndex(baseline.lostMask),baseline.deadlineMs, ...
    80,'x','LineWidth',1.8,'DisplayName','UDP record absent');
grid on; xlabel('P02 application record index'); ylabel('Age at application (ms)');
title('Baseline metric: eventual delivery is not the same as on-time delivery');
legend('Location','best');

figure('Name','P03 baseline delivery summary');
bar([baseline.tcpDeliveredCount baseline.tcpOnTimeCount; ...
    baseline.udpDeliveredCount baseline.udpOnTimeCount],0.75);
set(gca,'XTick',1:2,'XTickLabel',{'TCP byte stream','UDP datagrams'});
grid on; ylabel('Application records (count)');
title('Baseline metrics: eventual versus deadline-useful records');
legend({'Eventually delivered','Delivered on time'},'Location','southoutside');
disp(['Mechanism: UDP does not repair the missing datagram, so later datagrams remain visible. ' ...
    'TCP repairs the byte range after its timeout, but ordered delivery makes later bytes wait.']);

%% Sweep 1 - move only the application-period lever
messagePeriodsMs = [100 200 400];
periodSweepTcpOnTime = zeros(size(messagePeriodsMs));
periodSweepUdpOnTime = zeros(size(messagePeriodsMs));
periodSweepMaxHolMs = zeros(size(messagePeriodsMs));
for index = 1:numel(messagePeriodsMs)
    swept = model(6,messagePeriodsMs(index),20,3,1000,800);
    periodSweepTcpOnTime(index) = swept.tcpOnTimeCount;
    periodSweepUdpOnTime(index) = swept.udpOnTimeCount;
    periodSweepMaxHolMs(index) = swept.maxTcpHeadOfLineDelayMs;
end
figure('Name','P03 message-period deadline sweep');
plot(messagePeriodsMs,periodSweepTcpOnTime,'s-','LineWidth',1.4, ...
    'DisplayName','TCP on time'); hold on;
plot(messagePeriodsMs,periodSweepUdpOnTime,'d-','LineWidth',1.4, ...
    'DisplayName','UDP on time');
grid on; xlabel('Application record period (ms)'); ylabel('On-time records (count of 6)');
title('Sweep 1 changed view: spacing controls how many records queue behind loss');
legend('Location','best');

figure('Name','P03 message-period head-of-line sweep');
plot(messagePeriodsMs,periodSweepMaxHolMs,'o-','LineWidth',1.4, ...
    'MarkerFaceColor',[0.75 0.35 0.2]);
grid on; xlabel('Application record period (ms)');
ylabel('Maximum TCP head-of-line wait (ms)');
title('Sweep 1 mechanism metric: denser records accumulate behind the gap');
disp(['Mechanism: the 1000 ms timeout is fixed. A shorter record period lets more later byte ranges ' ...
    'arrive before the missing range is retransmitted.']);

%% Sweep 2 - reset the period and move only the TCP timeout lever
retransmissionTimeoutsMs = [1000 1250 1500];
timeoutSweepTcpOnTime = zeros(size(retransmissionTimeoutsMs));
timeoutSweepUdpOnTime = zeros(size(retransmissionTimeoutsMs));
timeoutSweepTcpMaxAgeMs = zeros(size(retransmissionTimeoutsMs));
for index = 1:numel(retransmissionTimeoutsMs)
    swept = model(6,200,20,3,retransmissionTimeoutsMs(index),800);
    timeoutSweepTcpOnTime(index) = swept.tcpOnTimeCount;
    timeoutSweepUdpOnTime(index) = swept.udpOnTimeCount;
    timeoutSweepTcpMaxAgeMs(index) = swept.maxTcpLatencyMs;
end
figure('Name','P03 retransmission-timeout deadline sweep');
plot(retransmissionTimeoutsMs,timeoutSweepTcpOnTime,'s-','LineWidth',1.4, ...
    'DisplayName','TCP on time'); hold on;
plot(retransmissionTimeoutsMs,timeoutSweepUdpOnTime,'d-','LineWidth',1.4, ...
    'DisplayName','UDP on time');
grid on; xlabel('Controlled TCP retransmission timeout (ms)');
ylabel('On-time records (count of 6)');
title('Sweep 2 changed view: a later TCP repair misses more deadlines');
legend('Location','best');

figure('Name','P03 retransmission-timeout age sweep');
plot(retransmissionTimeoutsMs,timeoutSweepTcpMaxAgeMs,'o-','LineWidth',1.4, ...
    'MarkerFaceColor',[0.25 0.55 0.75]);
grid on; xlabel('Controlled TCP retransmission timeout (ms)');
ylabel('Maximum TCP application age (ms)');
title('Sweep 2 mechanism metric: timeout adds directly to recovered-record age');
disp(['Mechanism: this controlled timeout delays only TCP recovery. The UDP timeline is unchanged ' ...
    'because this model does not add application-level retries to UDP.']);

%% Deliberately broken case - assume one TCP read equals one P02 frame
broken = model(6,200,20,3,1000,800);
boundary = broken.boundaryCase;
figure('Name','P03 broken message-boundary assumption');
bar([boundary.frameWriteBytes; boundary.tcpReadChunkBytes; ...
    boundary.udpDatagramReadBytes],0.75);
set(gca,'XTick',1:3,'XTickLabel',{'P02 writes','Permitted TCP reads','UDP reads'});
grid on; ylabel('Bytes per write or read');
title('Broken assumption: TCP read chunks need not match application writes');
legend({'First write or read','Second write or read'},'Location','southoutside');

figure('Name','P03 broken parser outcome');
bar([boundary.naiveTcpFramesRecovered boundary.bufferedTcpFramesRecovered ...
    boundary.udpFramesRecovered],0.65);
set(gca,'XTick',1:3,'XTickLabel',{'Naive TCP','Buffered TCP','UDP datagrams'});
grid on; ylabel('Complete P02 frames recovered (count of 2)');
title('Broken parser rejects valid stream chunks; length-aware buffering recovers');
disp(['Mechanism: TCP preserves an ordered byte stream, not P02 message boundaries. A receiver must ' ...
    'retain 9 bytes, append the next 21, and apply P02 framing; UDP preserves these datagram ' ...
    'boundaries in this adequate-buffer case.']);

assert(max(abs(baseline.tcpLatencyMs' - [20.12 20.12 1020.12 820.12 620.12 420.12])) < 1e-9);
assert(baseline.tcpDeliveredCount == 6 && baseline.tcpOnTimeCount == 4);
assert(baseline.udpDeliveredCount == 5 && baseline.udpOnTimeCount == 5);
assert(isequal(periodSweepTcpOnTime,[3 4 5]) && isequal(periodSweepUdpOnTime,[5 5 5]));
assert(isequal(timeoutSweepTcpOnTime,[4 3 2]) && isequal(timeoutSweepUdpOnTime,[5 5 5]));
assert(boundary.naiveTcpFramesRecovered == 0 && ...
    boundary.bufferedTcpFramesRecovered == 2 && boundary.udpFramesRecovered == 2);
