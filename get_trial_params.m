function [n_trials,baseln,itis,lick_pause_time] = get_trial_params(f)

p = f.Children(1).Children(2).Children(1).Children;

n_trials = p(19).Value;
baseln = p(21).Value./1000;
itis = [p(23).Value p(25).Value]./1000;
lick_pause_time = p(27).Value;



