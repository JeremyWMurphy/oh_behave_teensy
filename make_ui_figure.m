function fig = make_ui_figure(msg,fs,n_sec_disp)

default_id = [ 'NA_' char(datetime('now','format','yyyy-MM-dd''_T''HH-mm-ss'))];

% main figure
fig = uifigure('Position',[1920/4,1080/4, 1024, 512],'Color','black');
gl = uigridlayout(fig,[10 20],'BackgroundColor','black');

% subj name field
edt = uieditfield(gl, 'Value',default_id, ...
    'BackgroundColor',[0 0 0],...
    'FontColor',[1 1 1]);

edt.Layout.Row = 1;
edt.Layout.Column = [1 2];

% display and set save path field
pth_txt = uilabel(gl, ...
    'Text','C:\Users\jeremy\Documents\Data_Temp\',...    
    'BackgroundColor',[0 0 0],...
    'FontColor',[1 1 1]);

pth_txt.Layout.Row = 1;
pth_txt.Layout.Column = [4 10];

pth_btn = uibutton(gl,...
    'BackgroundColor',[0 0 0],...
    'Text', 'Set Path',...
    'FontColor',[1 1 1],...
    "ButtonPushedFcn", @(src,event) pthButtonPushed(pth_txt));

pth_btn.Layout.Row = 1;
pth_btn.Layout.Column = 3;

% serial console 

% start button
strt_btn = uibutton(gl,'state',...
    'BackgroundColor',[0 0 0],...
    'Text', 'Start',...
    'FontColor',[1 1 1],...
    'Value', false);

strt_btn.Layout.Row = 10;
strt_btn.Layout.Column = 1;

% stop button
stp_btn = uibutton(gl,'state',...
    'BackgroundColor',[0 0 0],...
    'Text', 'Stop',...
    'FontColor',[1 1 1],...
    'Value', false);

stp_btn.Layout.Row = 10;
stp_btn.Layout.Column = 2;

% main axes
ax = axes(gl);
ax.Layout.Row = [2 10];
ax.Layout.Column = [4 15];
ax.NextPlot = 'add';
ax.Color = [0 0 0];
ax.XColor = [1 1 1];
ax.YColor = [1 1 1];
ax.XLabel.String = 'SECS';
ax.YLim = [0 5];
ax.Title.Color = [1 1 1];
ax.Title.FontSize = 18;
ax.Title.FontWeight = 'normal';
ax.Title.String = 'Waiting to start';

ax.YTick = [1 2 3 4];
ax.YTickLabel = {'Piezo','Wheel','Frame1','Licks'};
nan_vec = nan(fs*n_sec_disp,1);

ax.XAxis.Visible  = 'off';

plot(ax,nan_vec,'m'); % piezo signal
plot(ax,nan_vec,'g'); % wheel
plot(ax,nan_vec,'c'); % frame raw
plot(ax,nan_vec,'y'); % lick detector

notes = uitextarea(gl);
notes.Layout.Column = [1 3];
notes.Layout.Row = [2 9];
notes.BackgroundColor = [0 0 0];
notes.FontColor = [0 1 0];

edt.ValueChangedFcn = @(src,event) update_id(edt,notes);

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

fontname(fig,'Courier')

end

function pthButtonPushed(txt)
    selpath = uigetdir('C:\Users\jeremy\Desktop\Data_Temp\');
    txt.Text = selpath;
end

function update_id(edt,notes)
    edt.Value = [edt.Value '_' char(datetime('now','format','yyyy-MM-dd''_T''HH-mm-ss'))];
    notes.Value = edt.Value;
end
















