function plotSaveDataAvailable(src, ~, fid, ax, up_every,f)

% OUTPUT from Teensy is,
% <loopNum, FrameNum, State, TrialOutcome, Ao0, Ao1, Ao2, Ao3, Licks, Wheel>

data = read(src,up_every,'char');
data = extractBetween(data,'<','>');

if ~isempty(data)

    data = cellfun(@(x) eval(['[' x ']']),data,'UniformOutput',false);
    data = cell2mat(data);

    fprintf(fid,'%u,%u,%u,%u,%u,%u,%u,%u,%u,%u\n',data');

    ax.Children(4).set('Ydata',[ax.Children(4).YData(size(data,1)+1:end) data(:,5)'./4095]); % ao0
    ax.Children(3).set('Ydata',[ax.Children(3).YData(size(data,1)+1:end) data(:,10)'./1024 + 1]); % wheel
    ax.Children(2).set('Ydata',[ax.Children(2).YData(size(data,1)+1:end) [diff(data(:,2)') 0] + 5]); % frames
    ax.Children(1).set('Ydata',[ax.Children(1).YData(size(data,1)+1:end) data(:,9)'+ 6]); % licks

    st = find(data(:,3) ~= 0,1,'first');
    if ~isempty(st)
        f.UserData.State = data(st,3);
    end

    if f.UserData.State < 4
        f.Children.Children(8).Children.Children(3:6).FontColor = [0.5 0.5 0.5];
        f.Children.Children(8).Children.Children(f.UserData.State+3).FontColor = [0 1 1];
    end

    ot = find(data(:,4) ~= 0,1,'first'); 
    if ~isempty(ot)
        f.UserData.trialOutcome = data(ot,4);
    end

    if f.UserData.Outcome > 0
        f.Children.Children(8).Children.Children(7:10).FontColor = [0.5 0.5 0.5];
        f.Children.Children(8).Children.Children(f.UserData.Outcome+6).FontColor = [0 1 1];
    end
     
    drawnow

end

end
