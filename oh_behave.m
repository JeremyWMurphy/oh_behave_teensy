function [] = oh_behave()

% parameters
teensy_fs = 5e3;

% experiment parameters
baseln = 5; % length of pause at begining of experiment

itis = [9 14]; % **important, this is actually ~= iti - 2 sec, in the world of teensy the iti values will also encompass stim/resp/rew time, so iti = 10 -> e.g., 2 sec stim/resp window, reward delivery of e.g., 500 ms, then the remainder 7.5 sec is actual ITI
n_trials = 200;

prcnt_go = 0.75;
sig_amps = [1 2 3 4 5];
sig_amps_12bit = map_jm(sig_amps,0,5,0,4095);

prcnt_amps = [0.2 0.2 0.2 0.2 0.2];

n_go_trls = round(n_trials*prcnt_go);
trls = [];
for i = 1:numel(sig_amps)
    trls = cat(1,trls,sig_amps(i)*ones(prcnt_amps(i)*n_go_trls,1));
end
n_nogo_trls = round(n_trials*(1-prcnt_go));
trls = cat(1,trls,zeros(n_nogo_trls,1));
trls = trls(randperm(n_trials));

% teensy state parameters
teensy_reset =      '<S,1>';
teensy_go_trial =   '<S,2>';
teensy_nogo_trial = '<S,3>';
teensy_trigger =    '<S,4>';

% teensy waveform stimulus parameters
chan = '0';
pulse_type = '0';
pulse_len = '25'; % ms
pulse_amp = '0';
pulse_intrvl = '25';
pulse_reps = '3';
pulse_base = '0';
msg_out = ['<W,' chan ',' pulse_type ',' pulse_len ',' pulse_amp ',' pulse_intrvl ',' pulse_reps ',' pulse_base '>'];

% device parameters
serial_port = 'COM3';
up_every = 4096;
n_sec_disp = 5;

%cam_fs = 10; % camera frame rate
%frame_duty_cycle = 0.2; % fraction of camera pulse high

%% live data figure
f = make_ui_figure(msg_out,teensy_fs,n_sec_disp);
f.UserData = struct('trialOutcome','State');

gl = get(f,'Children');

ax = gl.Children(1);
id_field = gl.Children(2);
pth_field = gl.Children(3);
btn_strt = gl.Children(5);
btn_stop = gl.Children(6);
notes = gl.Children(7);

%% wait for start button push
waitfor(btn_strt,'Value',1);

%% setup data files
id = id_field.Value;
save_pth = pth_field.Text;
exp_pth = [save_pth '/' id];
mkdir(exp_pth);
data_fid = fopen([exp_pth '/data.csv'],'w');
data_fid_stream = fopen([exp_pth '/data_stream.csv'],'w');
fprintf(data_fid,'%s\n',id);

%% serial comms w/ teensy
s = serialport(serial_port,115200);
pause(1);
s.configureCallback('byte',up_every, @(src,evt) plotSaveDataAvailable(src, evt, data_fid_stream, ax, up_every,f));
s.flush;

%%

write_serial(s,teensy_reset);
write_serial(s,teensy_trigger);

% pause for a baseline
pause(baseln);

for i = 1:n_trials

    tic
    fprintf(['\nTrial ' num2str(i) ' of ' num2str(n_trials)])

    trial_type = trls(i);
    if trial_type > 0
        is_go = true;        
        cur_amp = sig_amps_12bit(trial_type);
        msg_out = ['<W,' chan ',' pulse_type ',' pulse_len ',' num2str(cur_amp) ',' pulse_intrvl ',' pulse_reps ',' pulse_base '>'];
        ax.Title.String = ['Trial ' num2str(i) ', Go, Amp = ' num2str(cur_amp)];  
    else
        is_go = false;
        msg_out = ['<W,' chan ',' pulse_type ',' pulse_len ',0,' pulse_intrvl ',' pulse_reps ',' pulse_base '>'];
        ax.Title.String = ['Trial ' num2str(i) ', NoGo, Amp = 0'];
    end


    write_serial(s,msg_out);
    
    if is_go
        write_serial(s,teensy_go_trial);
    elseif ~is_go
        write_serial(s,teensy_nogo_trial);
    end

    % begin ITI
    iti = randi(itis,1);
    pause(iti)

    fprintf(['\nState: ' num2str(f.UserData.State) ', Last Trial Outcome: ' num2str(f.UserData.trialOutcome) '\n'])
            
    if btn_stop.Value
        fprintf('\nAborted...\n')
        please_kill_me(max(itis),s,data_fid,data_fid_stream,notes);
        return
    end

    toc

end

%% end of run
please_kill_me(max(itis),s,data_fid,data_fid_stream,notes);

end

%% Supporting functions

function[] = please_kill_me(p,s,data_fid,data_fid_stream,notes)

for i = 1:size(notes.Value,1)
    fprintf(data_fid,'%s\n',notes.Value{i});
end

%stop ni io
pause(p)
clear s

% close files
fclose(data_fid);
fclose(data_fid_stream);

all_fig = findall(0, 'type', 'figure');
close(all_fig)

end

%%
function[] = write_serial(s,msg)
write(s,msg,'string');
end