function[mo] = parse_teensy_stim_msg(mi)

msa = strsplit(mi,',');

if strcmp(msa{2},'0')
    wvn = 'Assym Cos';
elseif strcmp(msa{2},'1')
    wvn = 'Square';
elseif strcmp(msa{2},'2')
    wvn = 'Ramp up';
elseif strcmp(msa{2},'3')
    wvn = 'Ramp down';
elseif strcmp(msa{2},'4')
    wvn = 'Ramp up-down';
else
    wvn = 'Unknow waveform shape';

end

mo = ['Channel:' msa{1} ', Shape:' wvn ', AMP:' msa{4} ', UP:' msa{3} 'ms, DOWN:' msa{5} 'ms, REPS:' msa{6} ', BASE:' msa{7} 'ms'];