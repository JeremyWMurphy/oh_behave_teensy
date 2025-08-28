tic
fid = fopen('Data_Stream.csv');

data = fscanf(fid,'<%d,%d,%d,%d,%d,%d,%d,%d>\n');
r = mod(numel(data),8);
data = data(1:end-r);
data = reshape(data,8,[])';

strt = find(data(:,1)==0,1,'first');

data = data(8:end,:);

fclose(fid);

toc
