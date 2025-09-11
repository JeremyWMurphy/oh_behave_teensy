function plotSaveDataAvailable(src, ~, fid, ax, up_every,f)

% OUTPUT from Teensy is,
% <loopNum, FrameNum, State, TrialOutcome, Ao0, Ao1, Licks, Wheel>

data = read(src,up_every,'char');

if ~isempty(data)

    fprintf(fid,'%s',data');

    strt = find(data=='<',1,'first');
    fin = find(data=='>',1,'last');
    data = data(strt:fin);
    data = sscanf(data,'<%d,%d,%d,%d,%d,%d,%d,%d>\n');    
    data = reshape(data,8,[])';

    ax.Children(4).set('Ydata',[ax.Children(4).YData(size(data,1)+1:end) 1 + data(:,5)'./4095]); % ao0
    ax.Children(3).set('Ydata',[ax.Children(3).YData(size(data,1)+1:end) 3 + data(:,8)'./1024]); % wheel
    ax.Children(2).set('Ydata',[ax.Children(2).YData(size(data,1)+1:end) 5 + [diff(data(:,2)') 0]]); % frames
    ax.Children(1).set('Ydata',[ax.Children(1).YData(size(data,1)+1:end) 7 + data(:,7)']); % licks

    st = find(data(:,3) ~= 0,1,'first');
    if ~isempty(st)
        f.UserData.State = data(st,3);
        if f.UserData.State < 4
            f.UserData.Done = 0;
            f.Children.Children(8).Children.Children(3).FontColor = [0.5 0.5 0.5];
            f.Children.Children(8).Children.Children(4).FontColor = [0.5 0.5 0.5];
            f.Children.Children(8).Children.Children(5).FontColor = [0.5 0.5 0.5];
            f.Children.Children(8).Children.Children(6).FontColor = [0.5 0.5 0.5];
            f.Children.Children(8).Children.Children(f.UserData.State+3).FontColor = [0 1 1];
        end
    else
        f.Children.Children(8).Children.Children(3).FontColor = [0.5 0.5 0.5];
        f.Children.Children(8).Children.Children(4).FontColor = [0.5 0.5 0.5];
        f.Children.Children(8).Children.Children(5).FontColor = [0.5 0.5 0.5];
        f.Children.Children(8).Children.Children(6).FontColor = [0.5 0.5 0.5];
        f.UserData.State = data(st,3);

    end

    ot = find(data(:,4) ~= 0,1,'first'); 
    if ~isempty(ot)

        f.UserData.trialOutcome = data(ot,4);
        f.UserData.Done = 1;

        f.Children.Children(8).Children.Children(7).FontColor = [0.5 0.5 0.5];
        f.Children.Children(8).Children.Children(8).FontColor = [0.5 0.5 0.5];
        f.Children.Children(8).Children.Children(9).FontColor = [0.5 0.5 0.5];
        f.Children.Children(8).Children.Children(10).FontColor = [0.5 0.5 0.5];
        f.Children.Children(8).Children.Children(f.UserData.trialOutcome+6).FontColor = [0 1 1];
      
    else

        f.Children.Children(8).Children.Children(7).FontColor = [0.5 0.5 0.5];
        f.Children.Children(8).Children.Children(8).FontColor = [0.5 0.5 0.5];
        f.Children.Children(8).Children.Children(9).FontColor = [0.5 0.5 0.5];
        f.Children.Children(8).Children.Children(10).FontColor = [0.5 0.5 0.5];

    end

end


end
