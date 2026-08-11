function interactive
fig=uifigure('Name','P01 Distributed Timing','Position',[100 100 1160 720]);
g=uigridlayout(fig,[3 7]); g.RowHeight={'1x','1x',100};
axLatency=uiaxes(g); axLatency.Layout.Row=1; axLatency.Layout.Column=[1 7];
axError=uiaxes(g); axError.Layout.Row=2; axError.Layout.Column=[1 5];
summary=uilabel(g,'WordWrap','on'); summary.Layout.Row=2; summary.Layout.Column=[6 7];

d=uislider(g,'Limits',[0 10],'Value',2); d.Layout.Row=3; d.Layout.Column=1;
j=uislider(g,'Limits',[0 5],'Value',0.4); j.Layout.Row=3; j.Layout.Column=2;
s=uislider(g,'Limits',[-1000 1000],'Value',20); s.Layout.Row=3; s.Layout.Column=3;
o=uislider(g,'Limits',[-10 10],'Value',1); o.Layout.Row=3; o.Layout.Column=4;
dl=uislider(g,'Limits',[0.1 15],'Value',4); dl.Layout.Row=3; dl.Layout.Column=5;
p=uislider(g,'Limits',[1 100],'Value',10); p.Layout.Row=3; p.Layout.Column=6;
seed=uispinner(g,'Limits',[0 10000],'Value',84); seed.Layout.Row=3; seed.Layout.Column=7;
controls=[d j s o dl p];
for i=1:numel(controls)
    controls(i).ValueChangingFcn=@(~,~) updatePlots();
    controls(i).ValueChangedFcn=@(~,~) updatePlots();
end
seed.ValueChangedFcn=@(~,~) updatePlots();
updatePlots();

    function updatePlots
        out=model(d.Value,j.Value,s.Value,o.Value,dl.Value,p.Value,300,seed.Value);
        cla(axLatency); plot(axLatency,out.index,out.delay,'LineWidth',1.1);
        hold(axLatency,'on'); plot(axLatency,out.index,out.measuredLatency,'--','LineWidth',1.1);
        yline(axLatency,out.deadline,':'); hold(axLatency,'off');
        grid(axLatency,'on'); xlabel(axLatency,'Message index'); ylabel(axLatency,'Latency (ms)');
        title(axLatency,'Actual delay versus raw timestamp subtraction');
        legend(axLatency,{'Actual','Raw measured','Deadline'},'Location','best');

        cla(axError); plot(axError,out.sendTrue/1000,out.timestampError,'LineWidth',1.2);
        grid(axError,'on'); xlabel(axError,'Elapsed time (s)'); ylabel(axError,'Timestamp error (ms)');
        title(axError,'Clock offset plus accumulated skew');

        summary.Text=sprintf(['base delay %.2f ms\njitter %.2f ms\nskew %.1f ppm\n' ...
            'offset %.2f ms\nmiss fraction %.3f\nfinal clock error %.3f ms'], ...
            d.Value,j.Value,s.Value,o.Value,out.missFraction,out.timestampError(end));
    end
end
