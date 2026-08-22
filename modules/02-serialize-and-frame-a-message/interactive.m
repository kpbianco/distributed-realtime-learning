function interactive
%INTERACTIVE Explore serialization size, link occupancy, and bad framing.
fig = uifigure('Name','P02 Serialize and Frame a Message','Position',[100 100 1180 740]);
gridLayout = uigridlayout(fig,[4 6]);
gridLayout.RowHeight = {'1x','1x',24,44};

frameAxes = uiaxes(gridLayout);
frameAxes.Layout.Row = 1;
frameAxes.Layout.Column = [1 6];
budgetAxes = uiaxes(gridLayout);
budgetAxes.Layout.Row = 2;
budgetAxes.Layout.Column = [1 4];
summary = uilabel(gridLayout,'WordWrap','on');
summary.Layout.Row = 2;
summary.Layout.Column = [5 6];

sampleLabel = uilabel(gridLayout,'Text','Samples per message (count)');
sampleLabel.Layout.Row = 3;
sampleLabel.Layout.Column = [1 2];
rateLabel = uilabel(gridLayout,'Text','Link rate (kb/s)');
rateLabel.Layout.Row = 3;
rateLabel.Layout.Column = [3 4];
deltaLabel = uilabel(gridLayout,'Text','Extra bytes declared (count)');
deltaLabel.Layout.Row = 3;
deltaLabel.Layout.Column = 5;

sampleControl = uispinner(gridLayout,'Limits',[0 64],'Value',4,'Step',1, ...
    'RoundFractionalValues','on');
sampleControl.Layout.Row = 4;
sampleControl.Layout.Column = [1 2];
rateControl = uispinner(gridLayout,'Limits',[1 10000],'Value',1000,'Step',125);
rateControl.Layout.Row = 4;
rateControl.Layout.Column = [3 4];
deltaControl = uispinner(gridLayout,'Limits',[0 16],'Value',0,'Step',1, ...
    'RoundFractionalValues','on');
deltaControl.Layout.Row = 4;
deltaControl.Layout.Column = 5;
resetButton = uibutton(gridLayout,'Text','Reset baseline','ButtonPushedFcn',@resetBaseline);
resetButton.Layout.Row = 4;
resetButton.Layout.Column = 6;

sampleControl.ValueChangedFcn = @(~,~) render();
rateControl.ValueChangedFcn = @(~,~) render();
deltaControl.ValueChangedFcn = @(~,~) render();
render();

    function render
        out = model(sampleControl.Value,rateControl.Value,deltaControl.Value);

        cla(frameAxes);
        stem(frameAxes,0:out.actualFrameBytes-1,double(out.frame),'filled','LineWidth',1.1);
        grid(frameAxes,'on'); ylim(frameAxes,[-5 260]);
        xlabel(frameAxes,'Frame byte index (zero-based)');
        ylabel(frameAxes,'Byte value (decimal, 0-255)');
        title(frameAxes,'Explicit serialized and framed bytes');

        cla(budgetAxes);
        bar(budgetAxes,[out.actualFrameBytes out.expectedFrameBytes],0.6);
        budgetAxes.XTick = 1:2;
        budgetAxes.XTickLabel = {'Received','Receiver expects'};
        grid(budgetAxes,'on'); ylabel(budgetAxes,'Frame bytes');
        title(budgetAxes,sprintf('Receiver state: %s',char(out.receiverState)));

        summary.Text = sprintf([ ...
            'payload: %d bytes\nframe: %d bytes / %d bits\noverhead: %d bytes\n' ...
            'wire time: %.6f ms\nefficiency: %.1f%%\nmissing: %d bytes\n' ...
            'checksum evaluated: %d\naccepted: %d'], ...
            out.payloadBytes,out.actualFrameBytes,out.wireBits,out.protocolOverheadBytes, ...
            out.serializationTimeMs,100 * out.framingEfficiency,out.missingBytes, ...
            out.checksumEvaluated,out.receiverAccepted);
    end

    function resetBaseline(~,~)
        sampleControl.Value = 4;
        rateControl.Value = 1000;
        deltaControl.Value = 0;
        render();
    end
end
