function [] = oh_behave()

% parameters
teensy_fs = 5000;

% experiment parameters
baseln = 5; % length of pause at begining of experiment

itis = [9 14];
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
pulse_len = '20'; % ms
pulse_amp = '0';
pulse_intrvl = '0';
pulse_reps = '3';
pulse_base = '0';
msg_out = ['<W,' chan ',' pulse_type ',' pulse_len ',' pulse_amp ',' pulse_intrvl ',' pulse_reps ',' pulse_base '>'];

% device parameters
serial_port = 'COM4';
up_every = 5000; % number of bytes to read in at a time
n_sec_disp = 10;

%% live data figure
f = make_ui_figure(msg_out,teensy_fs,n_sec_disp);
f.UserData = struct('trialOutcome',0,'State',0,'lastFrame',NaN,'data',[]);

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
data_fid_stream = fopen([exp_pth '/data_stream.csv'],'w');

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

    % set waveform parameters
    write_serial(s,msg_out);
    
    % run appropriate trial type
    if is_go
        write_serial(s,teensy_go_trial);
    elseif ~is_go
        write_serial(s,teensy_nogo_trial);
    end

    while f.UserData.State > 0
        % wait for end of trial from teensy
    end

    % begin ITI
    iti = randi(itis,1);
    fprintf(['\nRequested ITI: ' num2str(iti) ' seconds, Actual '])
    pause(iti)
         
    if btn_stop.Value
        fprintf('\nAborted...\n')
        please_kill_me(max(itis),s,data_fid_stream,notes);
        return
    end

    toc

end

%% end of run
please_kill_me(max(itis),s,data_fid_stream,notes);

end

%% Supporting functions

function[] = please_kill_me(p,s,data_fid_stream,notes)

for i = 1:size(notes.Value,1)
    fprintf(data_fid,'%s\n',notes.Value{i});
end

%stop io
pause(p)
clear(s)

% close files
fclose(data_fid_stream);

all_fig = findall(0, 'type', 'figure');
close(all_fig)

end

%%
function[] = write_serial(s,msg)

write(s,msg,'string');

end