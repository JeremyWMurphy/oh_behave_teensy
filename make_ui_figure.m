function fig = make_ui_figure(fs,n_sec_disp,s)

default_id = 'NA';

%% main figure
ss = get(0,'screensize');
wd = ss(3);
ht = ss(4);

fig = uifigure('Position',[round(wd*0.25),round(ht*0.25),round(wd*0.67),round(ht*0.67)],'Color','black');

fig.UserData = struct('trialOutcome',0,'run_type',1,'state',0,'Done',0);

gl = uigridlayout(fig,[10 20],'BackgroundColor','black');

%% main axes
ax = axes(gl);
ax.Layout.Row = [2 10];
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

% display and set save path field
pth_txt = uilabel(gl, ...
    'Text','C:\Users\jeremy\Documents\Data_Temp\',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[1 1 1]);

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


%% notes text box

notes = uitextarea(gl);
notes.Layout.Column = [1 3];
notes.Layout.Row = [3 9];
notes.BackgroundColor = [0 0 0];
notes.FontColor = [0 1 0];

edt.ValueChangedFcn = @(src,event) update_id(edt,notes);

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

%% trial type feedback and outcome panel

p = uipanel(gl);
p.Layout.Row = [2 6];
p.Layout.Column = [16 19];
p.BackgroundColor = [0 0 0];
p.BorderColor = [1 1 1];

pgl = uigridlayout(p,[5 2],'BackgroundColor','black');

state_txt = uilabel(pgl, ...
    'Text','State',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[1 1 1]);
state_txt.Layout.Row = 1;
state_txt.Layout.Column = 1;
state_txt.FontSize = 18;

state_txt = uilabel(pgl, ...
    'Text','Outcome',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[1 1 1]);
state_txt.Layout.Row = 1;
state_txt.Layout.Column = 2;
state_txt.FontSize = 18;
 
state_txt = uilabel(pgl, ...
    'Text','Idle',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
state_txt.Layout.Row = 2;
state_txt.Layout.Column = 1;
state_txt.FontSize = 18;

state_txt = uilabel(pgl, ...
    'Text','Reset',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
state_txt.Layout.Row = 3;
state_txt.Layout.Column = 1;
state_txt.FontSize = 18;

state_txt = uilabel(pgl, ...
    'Text','Go',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
state_txt.Layout.Row = 4;
state_txt.Layout.Column = 1;
state_txt.FontSize = 18;

state_txt = uilabel(pgl, ...
    'Text','NoGo',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
state_txt.Layout.Row = 5;
state_txt.Layout.Column = 1;
state_txt.FontSize = 18;

state_txt = uilabel(pgl, ...
    'Text','Hit',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
state_txt.Layout.Row = 2;
state_txt.Layout.Column = 2;
state_txt.FontSize = 18;

state_txt = uilabel(pgl, ...
    'Text','Miss',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
state_txt.Layout.Row = 3;
state_txt.Layout.Column = 2;
state_txt.FontSize = 18;

state_txt = uilabel(pgl, ...
    'Text','CW',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
state_txt.Layout.Row = 4;
state_txt.Layout.Column = 2;
state_txt.FontSize = 18;

state_txt = uilabel(pgl, ...
    'Text','FA',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[0.5 0.5 0.5]);
state_txt.Layout.Row = 5;
state_txt.Layout.Column = 2;
state_txt.FontSize = 18;

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

%%

fontname(fig,'Arial');

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
        ax.Title.String = 'Lick Stream... ';
    end
end

function flowControl(fig,st)
  fig.UserData.state = st;
end
















