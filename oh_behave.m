function [] = oh_behave()

%% parameters

teensy_fs = 2000; % teensy sample rate, Hz

% experiment parameters
baseln = 5; % length of pause at begining of each run, sec
itis = [5 7]; % inter-trial interval, sec
n_trials = 300; % number of total trials to run
prcnt_go = 0.9; % percentage of trials that are go trials
sig_amps = [0.62 0.8 1 2 4]; % amplitudes of stimuli, Volts
prcnt_amps = [0.2 0.2 0.2 0.2 0.2]; % proportion of different amplitudes to present - needs to add to 1
lick_pause_time = 1000; % pause in ms for lick-reward pairing between lick and reward, this is usually fixed during detection, but may be used for other shaping runs

% initial teensy waveform stimulus parameters
chan = '0';
pulse_type = '0'; % 0 = whale, 1 = square, 2 = rampup, 3 = rampdown, 4 = pyramid
pulse_len = '20'; % ms
pulse_amp = '0'; % uint 12 bit
pulse_intrvl = '20'; % ms
pulse_reps = '3'; 
pulse_base = '0'; % ms

% device parameters
serial_port = 'COM3';
up_every = 5000; % number of bytes to read in at a time
n_sec_disp = 20; % number of seconds to display on the graph

%% make trial structure

% map requested voltage values to uint 12 bit
sig_amps_12bit = map_jm(sig_amps,0,5,0,4095);

% alot requested proportion of go and nogo trials
n_go_trls = round(n_trials*prcnt_go);
% fill go trials with requested proportions of signal amplitudes
trls = [];
for i = 1:numel(sig_amps)
    trls = cat(1,trls,i*ones(round(prcnt_amps(i)*n_go_trls),1));
end
n_nogo_trls = round(n_trials*(1-prcnt_go));
trls = cat(1,trls,zeros(n_nogo_trls,1));

% shuffle
trls = trls(randperm(n_trials));

%% serial coms w/ teensy

% teensy codes
teensy_reset =      '<S,1>';
teensy_go_trial =   '<S,2>';
teensy_nogo_trial = '<S,3>';
teensy_trigger =    '<S,4>';
teensy_pair_trial = '<S,8>';
teensy_lick_trial = '<S,9>';

% connect to teensy
s = serialport(serial_port,115200);
pause(1);

%% package parameters to send to gui figure
params.trial = struct('baseln',baseln,'itis',itis,'n_trials',n_trials,'prcnt_go',prcnt_go,'sig_amps',sig_amps,'lick_pause_time',lick_pause_time);
params.wave = struct('chan',str2num(chan),'pulse_type',str2num(pulse_type),'pulse_len',str2num(pulse_len),'pulse_amp',str2num(pulse_amp), ...
    'pulse_intrvl',str2num(pulse_intrvl),'pulse_reps',str2num(pulse_reps),'pulse_base',str2num(pulse_base));

%% make main gui figure
f = make_ui_figure(teensy_fs,n_sec_disp,s,params);

% get fig objs
tbs = get(f,'Children');
gl = tbs(1).Children(1).Children(1);
ax = gl.Children(1);
id_field = gl.Children(3);
pth_field = gl.Children(4);
notes = gl.Children(11);
hit_txt = gl.Children(19);
miss_txt = gl.Children(20);
cw_txt = gl.Children(21);
fa_txt = gl.Children(22);

%% Main
trial_is_done = 0;

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

    elseif f.UserData.state == 1 % beginning of a run

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

        % set stim params based on what's in the parameter tab group --
        % currently pulse_amp will do nothing
        [chan,pulse_type,pulse_len,pulse_amp,pulse_intrvl,pulse_reps,pulse_base] = get_wave_params(f);
        % set trial params based on what's in the parameter tab group --
        [n_trials,baseln,itis,lick_pause_time] = get_trial_params(f);

        % send triggers
        write_serial(s,teensy_trigger);
        pause(0.1)

        fprintf(data_fid_notes,['\nRun Began at ' char(datetime('now','Format','HH:mm:ss'))]);

        while present % trial loop

            if trl_cntr > n_trials
                present = 0;
            end

            trl_cntr = trl_cntr + 1;
           
            %% Detection Task
            if f.UserData.run_type == 1

                if trl_cntr == 1
                    fprintf(data_fid_notes,'\nDetection Task');
                    pause(baseln)
                end

                trial_type = trls(trl_cntr);
                if trial_type > 0
                    is_go = true;
                    cur_amp = sig_amps_12bit(trial_type);
                    msg_out = ['<W,' chan ',' pulse_type ',' pulse_len ',' num2str(cur_amp) ',' pulse_intrvl ',' pulse_reps ',' pulse_base '>'];
                    ax.Title.String = ['Trial ' num2str(trl_cntr) ', Go, Amp = ' num2str(cur_amp)];
                    fprintf(data_fid_notes,['\n Trial ' num2str(trl_cntr) ' ' char(datetime('now','Format','HH:mm:ss')) ', Go Trial, Amp = ' num2str(cur_amp)]);
                else
                    is_go = false;
                    msg_out = ['<W,' chan ',' pulse_type ',' pulse_len ',0,' pulse_intrvl ',' pulse_reps ',' pulse_base '>'];
                    ax.Title.String = ['Trial ' num2str(trl_cntr) ', NoGo, Amp = 0'];
                    fprintf(data_fid_notes,['\n Trial ' num2str(trl_cntr) ' ' char(datetime('now','Format','HH:mm:ss')) ', NoGo Trial, Amp = 0']);
                end

                % set waveform parameters
                write_serial(s,msg_out);

                % run appropriate trial type
                if is_go
                    write_serial(s,teensy_go_trial);
                elseif ~is_go
                    write_serial(s,teensy_nogo_trial);
                end

            %% Pairing Task
            elseif f.UserData.run_type == 2 

                if trl_cntr == 1
                    fprintf(data_fid_notes,'\nPairing Task');
                    pause(baseln)
                end

                trial_type = trls(trl_cntr);
                if trial_type > 0
                    cur_amp = sig_amps_12bit(trial_type);
                else
                    cur_amp = 0;
                end
                
                msg_out = ['<W,' chan ',' pulse_type ',' pulse_len ',' num2str(cur_amp) ',' pulse_intrvl ',' pulse_reps ',' pulse_base '>'];
                ax.Title.String = ['Trial ' num2str(trl_cntr) ', Go, Amp = ' num2str(cur_amp)];
                
                % set waveform parameters
                write_serial(s,msg_out);
                % initiate trial
                write_serial(s,teensy_pair_trial);

            %% Lick for Reward Task
            elseif  f.UserData.run_type == 3

                if trl_cntr == 1
                    fprintf(data_fid_notes,'\nLick for Reward Task');
                    msg_out = ['<W,' chan ',' pulse_type ',' pulse_len ',' pulse_amp ',' pulse_intrvl ',' pulse_reps ',' num2str(lick_pause_time) '>'];
                    write_serial(s,msg_out)
                    pause(baseln)
                else
                    ax.Title.String = ['Rewards Given = ' num2str(trl_cntr-1)];
                end

                write_serial(s,teensy_lick_trial);                
                fprintf(data_fid_notes,['\n' char(datetime('now','Format','HH:mm:ss')) ' Reward ' num2str(trl_cntr)] );          

            end

            %% remaining general trial structure -- the following stuff is common to all run types 
            %% (i.e., wait for trial end, get trial outcome, record outcome, do ITI) 
            while ~trial_is_done
                trial_is_done = f.UserData.Done;
                % wait for end of trial message from teensy before moving on
                % but make sure the serial callback has room to breath:
                pause(0.1)
                if f.UserData.state == 2 || f.UserData.state == 3 % this allows us to end the run or quit while waiting for trial outcome
                    break
                end
            end
                        
             trial_is_done = 0; 

            % color GUI outcome text based on this trials outcome
            if f.UserData.trialOutcome == 1
                hit_txt.FontColor = [0 1 1];
            elseif f.UserData.trialOutcome == 2
                miss_txt.FontColor = [0 1 1];
            elseif f.UserData.trialOutcome == 3
                cw_txt.FontColor = [0 1 1];
            elseif f.UserData.trialOutcome == 4
                fa_txt.FontColor = [0 1 1];
            end

            % check for run ending events
            if f.UserData.state == 2  % end the run
                ax.Title.String = 'Waiting to start';
                fprintf('\nAbort...')
                present = 0;
                configureCallback(s,'off');
                kill_run(s,data_fid_stream,data_fid_notes,notes);
            elseif trl_cntr > n_trials % end of run
                ax.Title.String = 'Task Complete';
                pause(3)
                ax.Title.String = 'Waiting to start';
                fprintf('\nEnd of run...')
                present = 0;
                configureCallback(s,'off');
                f.UserData.state = 2;
                kill_run(s,data_fid_stream,data_fid_notes,notes);
            elseif f.UserData.state == 3 % quit
                present = 0;
            end

            % begin ITI
            iti = randi(itis,1);
            pause(iti)

            % print the outcome of the trial to file
            fprintf(data_fid_notes,[', Outcome = ' num2str(f.UserData.trialOutcome)'] );

            % Change all outcome text back to gray
            hit_txt.FontColor = [0.5 0.5 0.5];
            miss_txt.FontColor = [0.5 0.5 0.5];
            cw_txt.FontColor = [0.5 0.5 0.5];
            fa_txt.FontColor = [0.5 0.5 0.5];
           

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

fprintf(fid2,['\nRun Ended at ' char(datetime('now','Format','HH:mm:ss')) '\n']);

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