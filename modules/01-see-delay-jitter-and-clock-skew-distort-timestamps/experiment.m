%% P01 - See Delay, Jitter, and Clock Skew Distort Timestamps
close all; clc;
out=model(2,0.4,20,1,4,10,300,84);

figure('Name','P01 baseline');
subplot(2,1,1);
plot(out.index,out.delay,'LineWidth',1.1,'DisplayName','Actual one-way delay'); hold on;
plot(out.index,out.measuredLatency,'--','LineWidth',1.1,'DisplayName','Raw timestamp difference');
yline(out.deadline,':','Deadline');
grid on; xlabel('Message index'); ylabel('Milliseconds');
title('Clock error masquerades as network latency'); legend('Location','best');
subplot(2,1,2);
plot(out.sendTrue/1000,out.timestampError,'LineWidth',1.2);
grid on; xlabel('Elapsed true time (s)'); ylabel('Timestamp error (ms)');
title('Frequency skew accumulates with time');

%% Sweep 1 - jitter
jit=[0.05 0.4 1.5];
figure('Name','P01 jitter sweep'); hold on; grid on;
for i=1:numel(jit)
    s=model(2,jit(i),0,0,4,10,1000,84);
    histogram(s.delay,50,'DisplayStyle','stairs','Normalization','probability', ...
        'LineWidth',1.2,'DisplayName',sprintf('jitter %.2f ms',jit(i)));
end
xline(4,'--','Deadline'); xlabel('Actual delay (ms)'); ylabel('Probability');
title('Jitter controls tail risk'); legend('Location','best');

%% Sweep 2 - clock skew
skews=[0 20 200];
fprintf('Clock-skew sweep after %.1f s:\n',out.sendTrue(end)/1000);
for i=1:numel(skews)
    s=model(2,0,skews(i),0,4,10,300,84);
    fprintf('  %g ppm -> final timestamp error %.3f ms\n',skews(i),s.timestampError(end));
end

%% Broken case - use raw remote timestamp subtraction
broken=model(2,0.2,500,3,4,10,1000,84);
figure('Name','P01 broken case');
plot(broken.index,broken.delay,'LineWidth',1.2,'DisplayName','Actual delay'); hold on;
plot(broken.index,broken.measuredLatency,'--','LineWidth',1.2,'DisplayName','Broken raw estimate');
grid on; xlabel('Message index'); ylabel('Milliseconds');
title('Broken: unsynchronized clocks invent a latency trend'); legend('Location','best');

assert(max(abs(out.correctedLatency-out.delay))<1e-9,'Exact known correction should recover delay.');
