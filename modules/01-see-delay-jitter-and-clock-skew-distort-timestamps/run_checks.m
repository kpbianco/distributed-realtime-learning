function run_checks
a=model(2,0,0,0,4,10,100,84);
assert(max(abs(a.delay-2))<eps,'Zero-jitter delay should be constant.');
assert(max(abs(a.measuredLatency-a.delay))<eps,'Synchronized clocks should measure exact delay.');
b=model(2,0,100,0,4,10,1000,84);
assert(abs(b.timestampError(end))>0.5,'Clock skew should accumulate visible error.');
assert(max(abs(b.correctedLatency-b.delay))<1e-9,'Known correction should recover true delay.');
c=model(5,0,0,0,4,10,100,84);
assert(c.missFraction==1,'Delay above deadline should always miss.');
disp('P01 checks passed.');
end
