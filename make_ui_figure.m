function fig = make_ui_figure(fs,n_sec_disp,s,params)

default_id = 'NA';
pth_main  = 'C:\Users\Jeremy\Documents\';

%% main figure
ss = get(0,'screensize');
wd = ss(3);
ht = ss(4);

fig = uifigure('Position',[round(wd*0.25),round(ht*0.25),round(wd*0.67),round(ht*0.67)],'Color','black');

fig.UserData = struct('trialOutcome',0,'run_type',1,'state',0,'Done',0);

tg = uitabgroup(fig,'Position',[0,0,round(wd*0.67),round(ht*0.67)]);
t1 = uitab(tg,'Title','Data','BackgroundColor','black');
t2 = uitab(tg,'Title',"Parameters",'BackgroundColor','black');

gl = uigridlayout(t1,[10 20],'BackgroundColor','black');
gl2 = uigridlayout(t2,[10 16],'BackgroundColor','black');

%% main data tab

%% main axes
ax = axes(gl);
ax.Layout.Row = [3 10];
ax.Layout.Column = [5 15];
ax.NextPlot = 'add';
ax.Color = [0 0 0];
ax.XColor = [1 1 1];
ax.YColor = [1 1 1];
ax.XLabel.String = 'SECS';
ax.YLim = [0 8];
ax.XLim = [1 fs*n_sec_disp];
ax.Title.Color = [1 1 1];
ax.Title.FontSize = 18;
ax.Title.FontWeight = 'normal';
ax.Title.String = 'Waiting to start';

ax.YTick = [1 3 5 7];
ax.YTickLabel = {'Piezo','Wheel','Frame1','Licks'};
nan_vec = nan(fs*n_sec_disp,1);

ax.XAxis.Visible  = 'off';

plot(ax,nan_vec,'m'); % piezo signal
plot(ax,nan_vec,'g'); % wheel
plot(ax,nan_vec,'c'); % frame raw
plot(ax,nan_vec,'y'); % lick detector

%% notes text box

notes = uitextarea(gl,'Value','Notes Here ...');
notes.Layout.Column = [1 4];
notes.Layout.Row = [3 9];
notes.BackgroundColor = [0 0 0];
notes.FontColor = [0 1 0];
%% set id name and save path

% id label
id_txt = uilabel(gl, ...
    'Text','Run ID:',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[1 1 1]);
id_txt.Layout.Row = 1;
id_txt.Layout.Column = 1;

% subj name edit field
edt = uieditfield(gl, 'Value',default_id, ...
    'BackgroundColor',[0 0 0],...
    'FontColor',[1 1 1]);
edt.Layout.Row = 1;
edt.Layout.Column = [2 4];
edt.ValueChangedFcn = @(src,event) update_id(edt,notes);

% display and set save path field
pth_txt = uilabel(gl, ...
    'Text',pth_main,...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[1 1 1], ...
    'FontSize', 16);
pth_txt.Layout.Row = 1;
pth_txt.Layout.Column = [6 20];

pth_btn = uibutton(gl,...
    'BackgroundColor',[0 0 0],...
    'Text', 'Set Path',...
    'FontColor',[1 1 1],...
    "ButtonPushedFcn", @(src,event) pthButtonPushed(pth_txt));
pth_btn.Layout.Row = 1;
pth_btn.Layout.Column = 5;

%% trial type toggle (Lick, Pair, Detect, live stream)

% display and set save path field
run_txt = uilabel(gl, ...
    'Text','Run Type:',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[1 1 1]);
run_txt.Layout.Row = 2;
run_txt.Layout.Column = 1;

tt1_btn = uibutton(gl,...
    'BackgroundColor',[0 0 0],...
    'Text', 'Lick',...
    'FontColor',[1 1 1],...
    "ButtonPushedFcn", @(src,event) ttButtonPushed(fig,3,ax));
tt1_btn.Layout.Row = 2;
tt1_btn.Layout.Column = 2;

tt2_btn = uibutton(gl,...
    'BackgroundColor',[0 0 0],...
    'Text', 'Pair',...
    'FontColor',[1 1 1],...
    "ButtonPushedFcn", @(src,event) ttButtonPushed(fig,2,ax));
tt2_btn.Layout.Row = 2;
tt2_btn.Layout.Column = 3;

tt3_btn = uibutton(gl,...
    'BackgroundColor',[0 0 0],...
    'Text', 'Detect',...
    'FontColor',[1 1 1],...
    "ButtonPushedFcn", @(src,event) ttButtonPushed(fig,1,ax));
tt3_btn.Layout.Row = 2;
tt3_btn.Layout.Column = 4;

tt4_btn = uibutton(gl,...
    'BackgroundColor',[0 0 0],...
    'Text', 'Live',...
    'FontColor',[1 1 1],...
    "ButtonPushedFcn", @(src,event) ttButtonPushed(fig,4,ax));
tt4_btn.Layout.Row = 2;
tt4_btn.Layout.Column = 5;

%% run start, run end, quit buttons

% start button
strt_btn = uibutton(gl,...
    'BackgroundColor',[0 0 0],...
    'Text', 'Begin',...
    'FontColor',[1 1 1],...
     "ButtonPushedFcn", @(src,event) flowControl(fig,1));
strt_btn.Layout.Row = 10;
strt_btn.Layout.Column = 1;

% stop button
stp_btn = uibutton(gl,...
    'BackgroundColor',[0 0 0],...
    'Text', 'End',...
    'FontColor',[1 1 1],...
     "ButtonPushedFcn", @(src,event) flowControl(fig,2));
stp_btn.Layout.Row = 10;
stp_btn.Layout.Column = 2;

% quit button
quit_btn = uibutton(gl,...
    'BackgroundColor',[0 0 0],...
    'Text', 'Quit',...
    'FontColor',[1 1 1],...
    "ButtonPushedFcn", @(src,event) flowControl(fig,3));
quit_btn.Layout.Row = 10;
quit_btn.Layout.Column = 3;

%% reward button, open valve, close valve

valve_txt = uilabel(gl, ...
    'Text','Reward Port:',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
valve_txt.Layout.Row = 9;
valve_txt.Layout.Column = [16 20];
valve_txt.FontSize = 18;
valve_txt.FontColor = [1 1 1];

rew_btn = uibutton(gl,...
    'BackgroundColor',[0 0 0],...
    'Text', 'Give Reward',...
    'FontColor',[1 1 1],...
    "ButtonPushedFcn", @(src,event) rewButtonPushed(s) ...    
);
rew_btn.Layout.Row = 10;
rew_btn.Layout.Column = [16 17];

open_btn = uibutton(gl,...
    'BackgroundColor',[0 0 0],...
    'Text', 'Open',...
    'FontColor',[1 1 1],...
    "ButtonPushedFcn", @(src,event) vOpenButtonPushed(s) ...    
);
open_btn.Layout.Row = 10;
open_btn.Layout.Column = 18;

close_btn = uibutton(gl,...
    'BackgroundColor',[0 0 0],...
    'Text', 'Close',...
    'FontColor',[1 1 1],...
    "ButtonPushedFcn", @(src,event) vCloseButtonPushed(s) ...    
);
close_btn.Layout.Row = 10;
close_btn.Layout.Column = 19;

%% outcome

hit_txt = uilabel(gl, ...
    'Text','Hit',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
hit_txt.Layout.Row = 2;
hit_txt.Layout.Column = [16 17];
hit_txt.FontSize = 32;
hit_txt.FontColor = [0.5 0.5 0.5];

miss_txt = uilabel(gl, ...
    'Text','Miss',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
miss_txt.Layout.Row = 2;
miss_txt.Layout.Column = [18 19];
miss_txt.FontSize = 32;
miss_txt.FontColor = [0.5 0.5 0.5];

cw_txt = uilabel(gl, ...
    'Text','CW',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
cw_txt.Layout.Row = 4;
cw_txt.Layout.Column = [16 17];
cw_txt.FontSize = 32;
cw_txt.FontColor = [0.5 0.5 0.5];

fa_txt = uilabel(gl, ...
    'Text','FA',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
fa_txt.Layout.Row = 4;
fa_txt.Layout.Column = [18 19];
fa_txt.FontSize = 32;
fa_txt.FontColor = [0.5 0.5 0.5];

%% parameter tab

fig_style = uistyle("BackgroundColor",[0 0.2 0],'FontColor',[1 1 1]);
rw = 2;
col = 1;

%% wave parameters
wave_params_txt = uilabel(gl2, ...
    'Text','Waveform Parameters:',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
wave_params_txt.Layout.Row = 1;
wave_params_txt.Layout.Column = [1 4];
wave_params_txt.FontSize = 20;
wave_params_txt.FontColor = [1 1 1];

%
channel_txt = uilabel(gl2, ...
    'Text','Chan:',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
channel_txt.Layout.Row = rw;
channel_txt.Layout.Column = col;
channel_txt.FontSize = 16;
channel_txt.FontColor = [1 1 1];
channel_txt.HorizontalAlignment = 'right';

channel_dd = uidropdown(gl2,'Items', ...
    {'0','1','2','3'}, ...
    'ItemsData',[0 1 2 3 ],'Value',params.wave.chan);
channel_dd.Layout.Row = rw;
channel_dd.Layout.Column = col+1;
addStyle(channel_dd,fig_style,'item',[1 2 3 4]);

%
wave_txt = uilabel(gl2, ...
    'Text','Shape:',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
wave_txt.Layout.Row = rw;
wave_txt.Layout.Column = col+2;
wave_txt.FontSize = 16;
wave_txt.FontColor = [1 1 1];
wave_txt.HorizontalAlignment = 'right';

wave_dd = uidropdown(gl2,'Items', ...
    {'Whale','Square','Ramp-up','Ramp-down','Pyramid'}, ...
    'ItemsData',[0 1 2 3 4],'Value',params.wave.pulse_type);
wave_dd.Layout.Row = rw;
wave_dd.Layout.Column = col+3;
addStyle(wave_dd,fig_style,'item',[1 2 3 4 5]);

%
amp_txt = uilabel(gl2, ...
    'Text','Amp:',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
amp_txt.Layout.Row = rw;
amp_txt.Layout.Column = col+4;
amp_txt.FontSize = 16;
amp_txt.FontColor = [1 1 1];
amp_txt.HorizontalAlignment = 'right';

amp_edt = uieditfield(gl2,'numeric','Value',params.wave.pulse_amp, ...
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5], 'Editable','off');
amp_edt.Layout.Row = rw;
amp_edt.Layout.Column = col+5;

%
duration_txt = uilabel(gl2, ...
    'Text','Dur:',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
duration_txt.Layout.Row = rw;
duration_txt.Layout.Column = col+6;
duration_txt.FontSize = 16;
duration_txt.FontColor = [1 1 1];
duration_txt.HorizontalAlignment = 'right';

duration_edt = uieditfield(gl2,'numeric','Value',params.wave.pulse_len, ...
    'BackgroundColor',[0 0.2 0],...
    'FontColor',[1 1 1]);
duration_edt.Layout.Row = rw;
duration_edt.Layout.Column = col+7;

%
ipi_txt = uilabel(gl2, ...
    'Text','IPI:',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
ipi_txt.Layout.Row = rw;
ipi_txt.Layout.Column = col+8;
ipi_txt.FontSize = 16;
ipi_txt.FontColor = [1 1 1];
ipi_txt.HorizontalAlignment = 'right';

ipi_edt = uieditfield(gl2,'numeric','Value',params.wave.pulse_intrvl, ...
    'BackgroundColor',[0 0.2 0],...
    'FontColor',[1 1 1]);
ipi_edt.Layout.Row = rw;
ipi_edt.Layout.Column = col+9;

%
np_txt = uilabel(gl2, ...
    'Text','N:',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
np_txt.Layout.Row = rw;
np_txt.Layout.Column = col+10;
np_txt.FontSize = 16;
np_txt.FontColor = [1 1 1];
np_txt.HorizontalAlignment = 'right';

np_edt = uieditfield(gl2,'numeric','Value',params.wave.pulse_reps, ...
    'BackgroundColor',[0 0.2 0],...
    'FontColor',[1 1 1]);
np_edt.Layout.Row = rw;
np_edt.Layout.Column = col+11;

%
base_txt = uilabel(gl2, ...
    'Text','Base:',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
base_txt.Layout.Row = rw;
base_txt.Layout.Column = col+12;
base_txt.FontSize = 16;
base_txt.FontColor = [1 1 1];
base_txt.HorizontalAlignment = 'right';

base_edt = uieditfield(gl2,'numeric','Value',params.wave.pulse_base, ...
    'BackgroundColor',[0 0.2 0],...
    'FontColor',[1 1 1]);
base_edt.Layout.Row = rw;
base_edt.Layout.Column = col+13;

%
wave_btn = uibutton(gl2,...
    'BackgroundColor',[0.2 0 0.2],...
    'Text', 'Send',...
    'FontColor',[1 1 1],...
    'FontSize', 16, ...
    "ButtonPushedFcn", @(src,event) setWaveParams(gl2,s) ...    
);
wave_btn.Layout.Row = 3;
wave_btn.Layout.Column = [4 5];

base_txt = uilabel(gl2, ...
    'Text','Set on Teensy:',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
base_txt.Layout.Row = 3;
base_txt.Layout.Column = [1 3];
base_txt.FontSize = 20;
base_txt.FontColor = [1 1 1];
base_txt.HorizontalAlignment = 'right';

%% trial parameters
rw = 5;

trial_params_txt = uilabel(gl2, ...
    'Text','Trial Parameters:',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
trial_params_txt.Layout.Row = 4;
trial_params_txt.Layout.Column = [1 4];
trial_params_txt.FontSize = 20;
trial_params_txt.FontColor = [1 1 1];

%
ntrls_txt = uilabel(gl2, ...
    'Text','N trials:',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
ntrls_txt.Layout.Row = rw;
ntrls_txt.Layout.Column = 1;
ntrls_txt.FontSize = 16;
ntrls_txt.FontColor = [1 1 1];
ntrls_txt.HorizontalAlignment = 'right';

bsln_edt = uieditfield(gl2,'numeric','Value',params.trial.n_trials, ...
    'BackgroundColor',[0 0.2 0],...
    'FontColor',[1 1 1]);
bsln_edt.Layout.Row = rw;
bsln_edt.Layout.Column = 2;

%
bsln_txt = uilabel(gl2, ...
    'Text','Base:',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
bsln_txt.Layout.Row = rw;
bsln_txt.Layout.Column = 3;
bsln_txt.FontSize = 16;
bsln_txt.FontColor = [1 1 1];
bsln_txt.HorizontalAlignment = 'right';

bsln_edt = uieditfield(gl2,'numeric','Value',params.trial.baseln*1000, ...
    'BackgroundColor',[0 0.2 0],...
    'FontColor',[1 1 1]);
bsln_edt.Layout.Row = rw;
bsln_edt.Layout.Column = 4;

%
iti_txt = uilabel(gl2, ...
    'Text','ITI:',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
iti_txt.Layout.Row = rw;
iti_txt.Layout.Column = 5;
iti_txt.FontSize = 16;
iti_txt.FontColor = [1 1 1];
iti_txt.HorizontalAlignment = 'right';

iti_edt = uieditfield(gl2,'numeric','Value',params.trial.itis(1)*1000, ...
    'BackgroundColor',[0 0.2 0],...
    'FontColor',[1 1 1]);
iti_edt.Layout.Row = rw;
iti_edt.Layout.Column = 6;

dash_txt = uilabel(gl2, ...
    'Text',' - ',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
dash_txt.Layout.Row = rw;
dash_txt.Layout.Column = 7;
dash_txt.FontSize = 30;
dash_txt.FontColor = [1 1 1];
dash_txt.HorizontalAlignment = 'center';

iti2_edt = uieditfield(gl2,'numeric','Value',params.trial.itis(2)*1000, ...
    'BackgroundColor',[0 0.2 0],...
    'FontColor',[1 1 1]);
iti2_edt.Layout.Row = rw;
iti2_edt.Layout.Column = 8;

%
lickp_txt = uilabel(gl2, ...
    'Text',' Rw time:',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
lickp_txt.Layout.Row = rw;
lickp_txt.Layout.Column = 9;
lickp_txt.FontSize = 16;
lickp_txt.FontColor = [1 1 1];
lickp_txt.HorizontalAlignment = 'right';

lickp_edt = uieditfield(gl2,'numeric','Value',params.trial.lick_pause_time, ...
    'BackgroundColor',[0 0.2 0],...
    'FontColor',[1 1 1]);
lickp_edt.Layout.Row = rw;
lickp_edt.Layout.Column = 10;

end

%% callbacks

function pthButtonPushed(txt)
    selpath = uigetdir('C:\Users\jeremy\Desktop\Data_Temp\');
    txt.Text = selpath;
end

function update_id(edt,notes)
    edt.Value = [edt.Value '_' char(datetime('now','format','yyyy-MM-dd''_T''HH-mm-ss'))];
    notes.Value = edt.Value;
end

function rewButtonPushed(s)
    write(s,'<S,7>','string');
end

function vOpenButtonPushed(s)
    write(s,'<S,5>','string');
end

function vCloseButtonPushed(s)
    write(s,'<S,6>','string');
end

function ttButtonPushed(fig,tt,ax)
    % set run type
    fig.UserData.run_type = tt;
    if tt == 1
        ax.Title.String = 'Detection Run... ';
    elseif tt == 2
        ax.Title.String = 'Pairing Run... ';
    elseif tt == 3
        ax.Title.String = 'Lick-for-reward Run... ';
    elseif tt == 4
        ax.Title.String = 'live streaming, not saving...';
    end

end

function flowControl(fig,st)
  fig.UserData.state = st;
end

function setWaveParams(g,s)

c = num2str(g.Children(3).Value);
w = num2str(g.Children(5).Value);
d = num2str(g.Children(9).Value);
a = num2str(g.Children(7).Value);
i = num2str(g.Children(11).Value);
n = num2str(g.Children(13).Value);
b = num2str(g.Children(15).Value);

msg = ['<W,' c ',' w ',' d ',' a ',' i ',' n ',' b '>'];
write(s,msg,'string');

end















