function [] = oh_behave()

% parameters
teensy_fs = 5000;

% experiment parameters
baseln = 5; % length of pause at begining of experiment

itis = [5 7];
n_trials = 300;

prcnt_go = 0.9;
sig_amps = [0.62 0.8 1 2 4];
sig_amps_12bit = map_jm(sig_amps,0,5,0,4095);
sig_amps_12bit = round(sig_amps_12bit);

prcnt_amps = [0.2 0.2 0.2 0.2 0.2];

n_go_trls = round(n_trials*prcnt_go);
trls = [];
for i = 1:numel(sig_amps)
    trls = cat(1,trls,i*ones(round(prcnt_amps(i)*n_go_trls),1));
end
n_nogo_trls = round(n_trials*(1-prcnt_go));
trls = cat(1,trls,zeros(n_nogo_trls,1));
trls = trls(randperm(n_trials));

% teensy state parameters
teensy_reset =      '<S,1>';
teensy_go_trial =   '<S,2>';
teensy_nogo_trial = '<S,3>';
teensy_trigger =    '<S,4>';

teensy_pair_trial =   '<S,8>';
teensy_lick_trial =   '<S,9>';

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
serial_port = 'COM3';
up_every = 5000; % number of bytes to read in at a time
n_sec_disp = 10;

%%
%% serial comms w/ teensy
s = serialport(serial_port,9600);
pause(1);
s.flush;
write_serial(s,teensy_reset);


%% live data figure
f = make_ui_figure(teensy_fs,n_sec_disp,s);

gl = get(f,'Children');

ax = gl.Children(1);
id_field = gl.Children(3);
pth_field = gl.Children(5);
btn_strt = gl.Children(11);
btn_stop = gl.Children(12);
btn_quit = gl.Children(13);
notes = gl.Children(10);

while ~btn_quit.Value

    if btn_strt.Value
        begin_run = 1;
    end

    if begin_run == 1

        %% setup data files
        id = [id_field.Value char(datetime('now','format','yyyy-MM-dd''_T''HH-mm-ss'))];
        id_field.Value = id;
        save_pth = pth_field.Text;
        exp_pth = [save_pth '/' id];
        mkdir(exp_pth);
        data_fid_stream = fopen([exp_pth '/data_stream.csv'],'w');
        data_fid_notes = fopen([exp_pth '/data_notes.csv'],'w');
        fprintf(data_fid_notes,id);

        s.configureCallback('byte',up_every, @(src,evt) plotSaveDataAvailable(src, evt, data_fid_stream, ax, up_every,f));

        write_serial(s,teensy_reset);
        write_serial(s,teensy_trigger);
        
        % pause for initial baseline
        pause(baseln);

        if f.UserData.run_type == 1 % detection task

            fprintf(data_fid_notes,'\nDetection Task');
            fprintf(data_fid_notes,['\nRun Begin at ' char(datetime('now','Format','HH:mm:ss'))]);

            for i = 1:n_trials

                fprintf(data_fid_notes,['\n Trial ' num2str(i) ' ' char(datetime('now','Format','HH:mm:ss'))]);

                trial_type = trls(i);
                if trial_type > 0
                    is_go = true;
                    cur_amp = sig_amps_12bit(trial_type);
                    msg_out = ['<W,' chan ',' pulse_type ',' pulse_len ',' num2str(cur_amp) ',' pulse_intrvl ',' pulse_reps ',' pulse_base '>'];
                    ax.Title.String = ['Trial ' num2str(i) ', Go, Amp = ' num2str(cur_amp)];
                    fprintf(data_fid_notes,[', Go Trial, Amp = ' num2str(cur_amp)] );
                else
                    is_go = false;
                    msg_out = ['<W,' chan ',' pulse_type ',' pulse_len ',0,' pulse_intrvl ',' pulse_reps ',' pulse_base '>'];
                    ax.Title.String = ['Trial ' num2str(i) ', NoGo, Amp = 0'];
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

                % wait a moment to allow teensy to enter trial state
                pause(0.1);

                while ~f.UserData.Done
                    % wait for end of trial message from teensy before moving on
                    % but make sure the serial callback has room to breath:
                    drawnow
                    pause(0.1)
                end

                fprintf(data_fid_notes,[', Outcome = ' num2str(f.UserData.trialOutcome)'] );

                % begin ITI
                iti = randi(itis,1);
                pause(iti)

                if btn_stop.Value %% end the run
                    fprintf('\nAborted...\n')
                    kill_run();
                    return
                end

            end

        elseif f.UserData.run_type == 2 % pairing task

            % pause for initial baseline
            pause(baseln);

            fprintf(data_fid_notes,'\nPairing Task');
            fprintf(data_fid_notes,['\nRun Begin at ' char(datetime('now','Format','HH:mm:ss'))]);

            for i = 1:n_trials

                fprintf(data_fid_notes,['\n Trial ' num2str(i) ' ' char(datetime('now','Format','HH:mm:ss'))]);

                trial_type = trls(i);
                cur_amp = sig_amps_12bit(trial_type);
                msg_out = ['<W,' chan ',' pulse_type ',' pulse_len ',' num2str(cur_amp) ',' pulse_intrvl ',' pulse_reps ',' pulse_base '>'];
                ax.Title.String = ['Trial ' num2str(i) ', Go, Amp = ' num2str(cur_amp)];

                % set waveform parameters
                write_serial(s,msg_out);
                write_serial(s,teensy_pair_trial);

                % wait a moment to allow teensy to enter trial state
                pause(0.1);

                while ~f.UserData.Done
                    % wait for end of trial message from teensy before moving on
                    % but make sure the serial callback has room to breath:
                    drawnow
                    pause(0.1)
                end

                % begin ITI
                iti = randi(itis,1);
                pause(iti)

                if btn_stop.Value
                    fprintf('\nAborted...\n')
                    kill_run();
                    return
                end

            end

        elseif  f.UserData.run_type == 3 % just lick for reward task

            write_serial(s,teensy_reset);
            write_serial(s,teensy_trigger);

            % pause for initial baseline
            pause(baseln);

            fprintf(data_fid_notes,'\nLick for Reward Task');
            fprintf(data_fid_notes,['\nRun Begin at ' char(datetime('now','Format','HH:mm:ss'))]);

            for i = 1:n_trials

                fprintf(data_fid_notes,['\n Trial ' num2str(i) ' ' char(datetime('now','Format','HH:mm:ss'))]);
                write_serial(s,teensy_lick_trial);

                % wait a moment to allow teensy to enter trial state
                pause(0.1);

                while ~f.UserData.Done
                    % wait for end of trial message from teensy before moving on
                    % but make sure the serial callback has room to breath:
                    drawnow
                    pause(0.1)
                end

                % begin ITI
                iti = randi(itis,1);
                pause(iti)

                if btn_stop.Value
                    fprintf('\nAborted...\n')
                    kill_run();
                    return
                end
            end
        end

        begin_run = 0;
        btn_strt.Value = 0;
        kill_run(s,data_fid_stream,data_fid_notes,notes,max(itis));

    end  
end

%% end program
kill_me(max(itis),s,data_fid_stream,data_fid_notes,notes);

end

%% Supporting functions

%% program quit function

function[] = kill_me(p,s,fid1,fid2,notes)

for i = 1:size(notes.Value,1)
    fprintf(fid2,'%s\n',notes.Value{i});
end

%stop io
write(s,'<S,1>','string');
write(s,'<S,0>','string');
pause(p)
clear('s')

% close files
fclose(fid1);
fclose(fid2);

all_fig = findall(0, 'type', 'figure');
close(all_fig)

end

%% end run function

function[] = kill_run(s,fid1,fid2,notes,p)

write(s,'<S,1>','string');
write(s,'<S,0>','string');

pause(p)

for i = 1:size(notes.Value,1)
    fprintf(fid2,'%s\n',notes.Value{i});
end

fprintf(fid2,['\nRun Ended at ' char(datetime('now','Format','HH:mm:ss'))]);

fclose(fid1);
fclose(fid2);

end

%% write to tensy
function[] = write_serial(s,msg)
write(s,msg,'string');
end