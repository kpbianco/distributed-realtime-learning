function interactive
%INTERACTIVE Move one transport lever at a time and compare the changed view.
transportModel = @model;
fig = uifigure('Name','P03 Compare TCP and UDP Behavior','Position',[100 100 1220 760]);
gridLayout = uigridlayout(fig,[4 8]);
gridLayout.RowHeight = {'1x','1x',24,44};

arrivalAxes = uiaxes(gridLayout);
arrivalAxes.Layout.Row = 1;
arrivalAxes.Layout.Column = [1 6];
latencyAxes = uiaxes(gridLayout);
latencyAxes.Layout.Row = 2;
latencyAxes.Layout.Column = [1 6];
summary = uilabel(gridLayout,'WordWrap','on');
summary.Layout.Row = [1 2];
summary.Layout.Column = [7 8];

periodLabel = uilabel(gridLayout,'Text','Application record period (ms)');
periodLabel.Layout.Row = 3;
periodLabel.Layout.Column = [1 2];
lossLabel = uilabel(gridLayout,'Text','Lost record index (0 = no loss)');
lossLabel.Layout.Row = 3;
lossLabel.Layout.Column = [3 4];
timeoutLabel = uilabel(gridLayout,'Text','TCP retransmission timeout (ms)');
timeoutLabel.Layout.Row = 3;
timeoutLabel.Layout.Column = [5 6];
deadlineLabel = uilabel(gridLayout,'Text','Deadline (ms)');
deadlineLabel.Layout.Row = 3;
deadlineLabel.Layout.Column = 7;

periodControl = uispinner(gridLayout,'Limits',[50 600],'Value',200,'Step',50);
periodControl.Layout.Row = 4;
periodControl.Layout.Column = [1 2];
lossControl = uispinner(gridLayout,'Limits',[0 6],'Value',3,'Step',1, ...
    'RoundFractionalValues','on');
lossControl.Layout.Row = 4;
lossControl.Layout.Column = [3 4];
timeoutControl = uispinner(gridLayout,'Limits',[1000 3000],'Value',1000,'Step',250);
timeoutControl.Layout.Row = 4;
timeoutControl.Layout.Column = [5 6];
deadlineControl = uispinner(gridLayout,'Limits',[100 2000],'Value',800,'Step',100);
deadlineControl.Layout.Row = 4;
deadlineControl.Layout.Column = 7;
resetButton = uibutton(gridLayout,'Text','Reset baseline','ButtonPushedFcn',@resetBaseline);
resetButton.Layout.Row = 4;
resetButton.Layout.Column = 8;

periodControl.ValueChangedFcn = @(~,~) render();
lossControl.ValueChangedFcn = @(~,~) render();
timeoutControl.ValueChangedFcn = @(~,~) render();
deadlineControl.ValueChangedFcn = @(~,~) render();
render();

    function render
        out = transportModel(6,periodControl.Value,20,lossControl.Value, ...
            timeoutControl.Value,deadlineControl.Value);

        cla(arrivalAxes);
        plot(arrivalAxes,out.recordIndex,out.tcpApplicationDeliveryTimeMs,'s-', ...
            'LineWidth',1.4,'DisplayName','TCP contiguous delivery');
        hold(arrivalAxes,'on');
        plot(arrivalAxes,out.recordIndex,out.udpDeliveryTimeMs,'d-', ...
            'LineWidth',1.4,'DisplayName','UDP datagram delivery');
        if any(out.lostMask)
            scatter(arrivalAxes,out.recordIndex(out.lostMask), ...
                out.baseArrivalTimeMs(out.lostMask),80,'x','LineWidth',1.8, ...
                'DisplayName','Lost first attempt');
        end
        hold(arrivalAxes,'off');
        grid(arrivalAxes,'on');
        xlabel(arrivalAxes,'P02 application record index');
        ylabel(arrivalAxes,'Time from first send (ms)');
        title(arrivalAxes,'Application-visible arrival timeline');
        legend(arrivalAxes,'Location','best');

        cla(latencyAxes);
        plot(latencyAxes,out.recordIndex,out.tcpLatencyMs,'s-', ...
            'LineWidth',1.4,'DisplayName','TCP age');
        hold(latencyAxes,'on');
        plot(latencyAxes,out.recordIndex,out.udpLatencyMs,'d-', ...
            'LineWidth',1.4,'DisplayName','UDP age');
        yline(latencyAxes,out.deadlineMs,':','Application deadline','LineWidth',1.2);
        if any(out.lostMask)
            scatter(latencyAxes,out.recordIndex(out.lostMask), ...
                out.deadlineMs,80,'x','LineWidth',1.8,'DisplayName','UDP absent');
        end
        hold(latencyAxes,'off');
        grid(latencyAxes,'on');
        xlabel(latencyAxes,'P02 application record index');
        ylabel(latencyAxes,'Age at application (ms)');
        title(latencyAxes,'Deadline consequence of loss and TCP head-of-line blocking');
        legend(latencyAxes,'Location','best');

        summary.Text = sprintf([ ...
            'P02 frame: %d bytes\nno-loss service: %.2f ms\n\n' ...
            'TCP eventual/on-time: %d/%d, %d/%d\nTCP retransmissions: %d\n' ...
            'TCP HOL-buffered: %d records / %d app bytes\nmax TCP age: %.2f ms\n\n' ...
            'UDP eventual/on-time: %d/%d, %d/%d\nUDP lost: %d\n\n' ...
            'Analytical only: no socket or real wait'], ...
            out.applicationFrameBytes,out.serviceDelayMs, ...
            out.tcpDeliveredCount,out.messageCount,out.tcpOnTimeCount,out.messageCount, ...
            out.tcpRetransmissionCount,out.tcpOutOfOrderBufferedRecordCount, ...
            out.tcpOutOfOrderBufferedApplicationBytes,out.maxTcpLatencyMs, ...
            out.udpDeliveredCount,out.messageCount,out.udpOnTimeCount,out.messageCount, ...
            out.udpLostCount);
    end

    function resetBaseline(~,~)
        periodControl.Value = 200;
        lossControl.Value = 3;
        timeoutControl.Value = 1000;
        deadlineControl.Value = 800;
        render();
    end
end
