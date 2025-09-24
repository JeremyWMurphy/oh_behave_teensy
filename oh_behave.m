function [] = oh_behave()

% parameters
teensy_fs = 5000;

% experiment parameters
baseln = 5; % length of pause at begining of each run
itis = [5 7];
n_trials = 300;
prcnt_go = 0.9;
sig_amps = [0.62 0.8 1 2 4];
prcnt_amps = [0.2 0.2 0.2 0.2 0.2];

lick_pause_time = 1000; % pause in ms for lick-reward pairing between lick and reward

% teensy waveform stimulus parameters
chan = '0';
pulse_type = '0';
pulse_len = '20'; % ms
pulse_amp = '0';
pulse_intrvl = '0';
pulse_reps = '3';
pulse_base = '0';
% stim set message structure: msg_out = ['<W,' chan ',' pulse_type ',' pulse_len ',' pulse_amp ',' pulse_intrvl ',' pulse_reps ',' pulse_base '>'];

% device parameters
serial_port = 'COM3';
up_every = 8000; % number of bytes to read in at a time
n_sec_disp = 10; % number of seconds to display on the graph

%% make trial structure
sig_amps_12bit = map_jm(sig_amps,0,5,0,4095);
n_go_trls = round(n_trials*prcnt_go);
trls = [];
for i = 1:numel(sig_amps)
    trls = cat(1,trls,i*ones(round(prcnt_amps(i)*n_go_trls),1));
end
n_nogo_trls = round(n_trials*(1-prcnt_go));
trls = cat(1,trls,zeros(n_nogo_trls,1));
trls = trls(randperm(n_trials));

%% serial comms w/ teensy

% teensy codes
teensy_reset =      '<S,1>';
teensy_go_trial =   '<S,2>';
teensy_nogo_trial = '<S,3>';
teensy_trigger =    '<S,4>';
teensy_pair_trial =   '<S,8>';
teensy_lick_trial =   '<S,9>';

% connect to teensy
s = serialport(serial_port,115200);
pause(1);

% task outcomes
outcomes = {'Hit','Miss','CW','FA'};

%% make main gui figure
f = make_ui_figure(teensy_fs,n_sec_disp,s);

% get fig objs
gl = get(f,'Children');
ax = gl.Children(1);
id_field = gl.Children(3);
pth_field = gl.Children(4);
notes = gl.Children(11);

%% Main
while f.UserData.state ~= 3

    if f.UserData.run_type == 4 % just stream the data  
        s.flush;
        write_serial(s,teensy_reset); % resetting teensy        
        ax.Title.String = 'live streaming, not saving...';
        s.configureCallback('byte',up_every, @(src,evt) justStream(src, evt, ax, up_every));
        present = 1;
        while present 
            pause(0.1)
            if f.UserData.state == 2 || f.UserData.state == 3
                present = 0;
                ax.Title.String = 'Waiting to start';
                fprintf('\nAborted...\n')
                configureCallback(s,'off');
                f.UserData.run_type = 0;
            end
        end
        continue

    elseif f.UserData.state == 1

        trl_cntr = 0;
        present = 1;

        %% setup data files
        id = [id_field.Value '_' char(datetime('now','format','yyyy-MM-dd''_T''HH-mm-ss'))];
        save_pth = pth_field.Text;
        exp_pth = [save_pth '/' id];
        mkdir(exp_pth);
        data_fid_stream = fopen([exp_pth '/data_stream.csv'],'w');
        data_fid_notes = fopen([exp_pth '/data_notes.csv'],'w');
        fprintf(data_fid_notes,id);

        s.flush;
        write_serial(s,teensy_reset); % resetting teensy   
        s.configureCallback('byte',up_every, @(src,evt) plotSaveDataAvailable(src, evt, data_fid_stream, ax, up_every,f));

        % send triggers
        write_serial(s,teensy_trigger);
        pause(0.1)

        fprintf(data_fid_notes,['\nRun Began at ' char(datetime('now','Format','HH:mm:ss'))]);

        while present

            if trl_cntr > n_trials
                present = 0;
            end

            trl_cntr = trl_cntr + 1;

            if f.UserData.run_type == 1 % detection task

                if trl_cntr == 1
                    fprintf(data_fid_notes,'\nDetection Task');
                    pause(baseln)
                end

                fprintf(data_fid_notes,['\n Trial ' num2str(trl_cntr) ' ' char(datetime('now','Format','HH:mm:ss'))]);

                trial_type = trls(trl_cntr);
                if trial_type > 0
                    is_go = true;
                    cur_amp = sig_amps_12bit(trial_type);
                    msg_out = ['<W,' chan ',' pulse_type ',' pulse_len ',' num2str(cur_amp) ',' pulse_intrvl ',' pulse_reps ',' pulse_base '>'];
                    ax.Title.String = ['Trial ' num2str(trl_cntr) ', Go, Amp = ' num2str(cur_amp)];
                    fprintf(data_fid_notes,[', Go Trial, Amp = ' num2str(cur_amp)] );
                else
                    is_go = false;
                    msg_out = ['<W,' chan ',' pulse_type ',' pulse_len ',0,' pulse_intrvl ',' pulse_reps ',' pulse_base '>'];
                    ax.Title.String = ['Trial ' num2str(trl_cntr) ', NoGo, Amp = 0'];
                    fprintf(data_fid_notes,', NoGo Trial, Amp = 0');
                end

                % set waveform parameters
                write_serial(s,msg_out);

                % run appropriate trial type
                if is_go
                    write_serial(s,teensy_go_trial);
                elseif ~is_go
                    write_serial(s,teensy_nogo_trial);
                end

            elseif f.UserData.run_type == 2 % pairing task

                if trl_cntr == 1
                    fprintf(data_fid_notes,'\nPairing Task');
                    pause(baseln)
                end

                trial_type = trls(trl_cntr);
                cur_amp = sig_amps_12bit(trial_type);
                msg_out = ['<W,' chan ',' pulse_type ',' pulse_len ',' num2str(cur_amp) ',' pulse_intrvl ',' pulse_reps ',' pulse_base '>'];
                ax.Title.String = ['Trial ' num2str(trl_cntr) ', Go, Amp = ' num2str(cur_amp)];
                
                % set waveform parameters
                write_serial(s,msg_out);
                write_serial(s,teensy_pair_trial);

            elseif  f.UserData.run_type == 3 % just lick for reward task

                if trl_cntr == 1
                    fprintf(data_fid_notes,'\nLick for Reward Task');
                    msg_out = ['<W,' chan ',' pulse_type ',' pulse_len ',' pulse_amp ',' pulse_intrvl ',' pulse_reps ',' lick_pause_time '>'];
                    write_serial(s,msg_out)
                    pause(baseln)
                end

                write_serial(s,teensy_lick_trial);
                ax.Title.String = ['N Rewards = ' num2str(trl_cntr)];
                fprintf(data_fid_notes,['\n' char(datetime('now','Format','HH:mm:ss')) ' Reward ' num2str(trl_cntr)] );
                

            end

            while ~f.UserData.Done
                % wait for end of trial message from teensy before moving on
                % but make sure the serial callback has room to breath:
                pause(0.1)
                if f.UserData.state == 2 || f.UserData.state == 3
                    break
                end
            end
            
            f.UserData.Done = 0;

            fprintf(data_fid_notes,[', Outcome = ' num2str(f.UserData.trialOutcome)'] );

            if f.UserData.state == 2 || trl_cntr > n_trials %% end the run
                ax.Title.String = 'Waiting to start';
                fprintf('\nAborted...\n')
                present = 0;
                configureCallback(s,'off');
                kill_run(s,data_fid_stream,data_fid_notes,notes);
            elseif f.UserData.state == 3
                present = 0;
            end

            % begin ITI
            iti = randi(itis,1);
            pause(iti)

        end
    end
    pause(0.1)
end

%% end program
try exist(data_fid_stream,'var')
    kill_program(s,notes,data_fid_stream,data_fid_notes);
catch
    kill_program(s);
end

end

%% Supporting functions

%% end run function
function[] = kill_run(s,fid1,fid2,notes)

write(s,'<S,1>','string');
write(s,'<S,0>','string');

fprintf(fid2,['\nRun Ended at ' char(datetime('now','Format','HH:mm:ss'))]);

for i = 1:size(notes.Value,1)
    fprintf(fid2,'%s\n',notes.Value{i});
end

fclose(fid1);
fclose(fid2);

end

%% program quit functions
function[] = kill_program(s,notes,fid1,fid2)

fprintf('\nQuitting...\n')

if nargin > 1
    for i = 1:size(notes.Value,1)
        fprintf(fid2,'%s\n',notes.Value{i});
    end
    % close files
    fclose(fid1);
    fclose(fid2);
end

%stop io
write(s,'<S,1>','string');
write(s,'<S,0>','string');
clear s

all_fig = findall(0, 'type', 'figure');
close(all_fig)

end

%% write to tensy
function[] = write_serial(s,msg)
write(s,msg,'string');
end