function fig = make_ui_figure(msg,fs,n_sec_disp)

default_id = [ 'NA_' char(datetime('now','format','yyyy-MM-dd''_T''HH-mm-ss'))];

% main figure
fig = uifigure('Position',[1920/4,1080/4, 1500, 512],'Color','black');
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
ax.Layout.Column = [3 15];
ax.NextPlot = 'add';
ax.Color = [0 0 0];
ax.XColor = [1 1 1];
ax.YColor = [1 1 1];
ax.XLabel.String = 'SECS';
ax.YLim = [-1 8];
ax.Title.String = parse_teensy_stim_msg(msg);
ax.Title.Color = [1 1 1];
ax.Title.FontSize = 12;
ax.Title.FontWeight = 'normal';

ax.YTick = [0 1 3 5 7];
ax.YTickLabel = {'Piezo','Wheel','Frame1','Licks'};
nan_vec = nan(fs*n_sec_disp,1);

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

% v = videoinput("winvideo", 1, "MJPG_1024x576");
% v.ReturnedColorspace = "rgb";
% v.ROIPosition = [0 0 512 512];
% ax2 = axes(gl);
% ax2.Layout.Row = [1 10];
% ax2.Layout.Column = [14 20]; 
% im = image(ax2,zeros(512,512,'uint8')); 
% axis(ax2,'image');
% preview(v,im);

end

function pthButtonPushed(txt)
    selpath = uigetdir('C:\Users\jeremy\Documents\Data_Temp\');
    txt.Text = selpath;
end

function update_id(edt,notes)
    edt.Value = [edt.Value '_' char(datetime('now','format','yyyy-MM-dd''_T''HH-mm-ss'))];
    notes.Value = edt.Value;
end
















