function [S] = read_data(verbose,pth)

if nargin < 2
    pth = uigetdir();
end

Fs = 2e3; % teensy Fs

% OUTPUT from Teensy is,
% <loopNum, FrameNum, State, TrialOutcome, Ao0, Ao1, Licks, Wheel>

fid = fopen([pth '\Data_Stream.csv']);
data = fscanf(fid,'<%d,%d,%d,%d,%d,%d,%d,%d>\n');
fclose(fid);

tnfo  = dir([pth '\*TSeries*']);
tnfo  = dir([tnfo.folder '\' tnfo.name '\*.xml']);
s = readstruct([tnfo.folder '\' tnfo.name]);

% get frame period
idx = find([s.PVStateShard.PVStateValue.keyAttribute]=="framePeriod");
frame_period = s.PVStateShard.PVStateValue(idx).valueAttribute;
im_fs = 1/frame_period;

idx = find([s.PVStateShard.PVStateValue.keyAttribute]=="rastersPerFrame");
n_frame_avg = s.PVStateShard.PVStateValue(idx).valueAttribute;

im_fs = im_fs/n_frame_avg;

%%

r = mod(numel(data),8); % find an incomplete line at the end
data = data(1:end-r);
data = reshape(data,8,[])';
strt = find(data(:,1)==0,1,'first'); % find teensy restart (this is always done at the start of the experiment)
data = data(strt:end,:);
data = array2table(data,'VariableNames',{'LoopNum','FrameNum','State','TrialOutcome','Ao0','Ao1','Licks','Wheel'});

frames = find(diff(data.FrameNum)==1) + 1;
frames(diff(frames)<median(diff(frames))/2) = [];
r = mod(numel(frames),n_frame_avg);
frames = frames(1:end-r);

im_fr_teensy = median(diff(frames))/Fs;

frames = frames(1:n_frame_avg:end);

outcomes = find(diff(data.TrialOutcome)>0) + 1;

win = -2*Fs:Fs*3;

behavior = nan(numel(outcomes),6);

for i = 1:numel(outcomes)

    ttype = data.TrialOutcome(outcomes(i));
    behavior(i,1) = outcomes(i);

    behavior(i,2) = ttype;

    twin = outcomes(i)+win;

    if ttype < 3

        amp = max(data.Ao0(twin));
        behavior(i,3) = amp;
        ponset = twin(find(data.Ao0(twin)>0,1,'first'))-1;
        behavior(i,5) = find(abs(frames-ponset) == min(abs(frames-ponset))); % frame of piezo

        if ttype == 1

            lick_ix = twin(find(data.Licks(twin)>0,1,'first'));
            rt = (lick_ix-ponset)/Fs;
            
            if rt < 0.1
                rt = NaN;
                behavior(i,2) = 2;
            end

            behavior(i,4) = rt;
            behavior(i,6) = find(abs(frames-lick_ix) == min(abs(frames-lick_ix))); % frame of first lick

        end


    end
end

amp_levels = unique(behavior(behavior(:,2)==1|behavior(:,2)==2,3));
amp_levels(amp_levels==0) = [];
thresh_beh = zeros(numel(amp_levels),2);

for i = 1:size(behavior,1)

    if behavior(i,2) < 3
        amp = find(behavior(i,3)==amp_levels);
        
        if behavior(i,2) == 1
        
            thresh_beh(amp,1) = thresh_beh(amp,1) + 1;

        elseif behavior(i,2) == 2

            thresh_beh(amp,2) = thresh_beh(amp,2) + 1;

        end
    end
end

phit = thresh_beh(:,1)./(thresh_beh(:,1)+thresh_beh(:,2));

figure, hold on
plot(1:numel(amp_levels),phit,'ok')
mod_fit = fit((1:numel(amp_levels))',phit,'logistic');
plot(0:numel(amp_levels),mod_fit(0:numel(amp_levels)),'r')

if verbose

    t = data.LoopNum/Fs;

    f = figure('Color','black');
    
    ax = axes(f);
    hold on

    plot(ax,t,rescale(data.State),'c')
    plot(ax,t,rescale(data.Ao0)+2,'m')
   
    plot(ax,t,rescale(data.TrialOutcome)+4,'g')
    plot(ax,t,rescale(data.Licks)+6,'y')

    ax.Color = [0 0 0];
    ax.XColor = [1 1 1];
    ax.YColor = [1 1 1];
    ax.XLabel.String = 'Time (Seconds)';
    ax.YLim = [-1 8];
    ax.YTick = [0 2 4 6];
    ax.YTickLabel = {'State','Piezo','Trial Outcome','Licking'};

    for i = 1:size(behavior,1)
        tmp = behavior(i,:);
        t_tmp = t(tmp(1));

        if tmp(2) == 1
            text(t_tmp+2,7,'HIT','Color',[1 1 1]);
        elseif tmp(2) == 2
            text(t_tmp+2,7,'MISS','Color',[1 1 1]);
        elseif tmp(2) == 3
            text(t_tmp+2,7,'CW','Color',[1 1 1]);
        elseif tmp(2) == 4
            text(t_tmp+2,7,'FA','Color',[1 1 1]);
        end
    end

end

behavior = array2table(behavior,'VariableNames',{'teensy_index','outcome','piezo_amp','rt','piezo_frame','lick_frame'});

S.raw_data = data;
S.behavior = behavior;
S.frames = frames;
S.p_hit = phit;
S.amp_levels = amp_levels;
S.model_fit = mod_fit;
S.fs = Fs;
S.im_fs = im_fs;
S.n_frame_avg = n_frame_avg;
S.im_fr_teensy = im_fr_teensy;
S.frame_period = frame_period;

save([pth 'teensy_data.mat'],'S')








