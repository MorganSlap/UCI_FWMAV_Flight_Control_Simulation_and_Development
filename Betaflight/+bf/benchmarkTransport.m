function report=benchmarkTransport()
%BENCHMARKTRANSPORT Compare identical packets without profiling overhead.
config=bf.hoverConfig(); rc=[1500;1500;1000;1500;1000;1000;1000*ones(10,1)];
names={'matlab','java'}; outputs=cell(1,2); seconds=zeros(1,2);
for transport=1:2
    client=bf.Client(config,5,names{transport}); cleanup=onCleanup(@()delete(client));
    data=zeros(500,40); started=tic;
    for k=0:499
        response=client.step(k/4000,zeros(3,1),[0;0;-9.80665],rc,zeros(12,1),8*double(mod(k,40)==0));
        data(k+1,:)=response';
    end
    seconds(transport)=toc(started); outputs{transport}=data;
    delete(cleanup);
end
assert(isequal(outputs{1},outputs{2}),'Transport changed firmware replies.');
report=struct('Packets',500,'MatlabSeconds',seconds(1),'JavaSeconds',seconds(2), ...
    'Speedup',seconds(1)/seconds(2),'RepliesExactlyEqual',true);
writelines(jsonencode(report,PrettyPrint=true),fullfile(bf.paths().Root,'test-output','transport-benchmark.json'));
disp(report);
end
