% script gmj_genetic_test.m
%
% copyright 2017, Mingjie Gao, university of michigan

warning('off');
clear all; clc

% setup
if (~exist('irtdir', 'var'))
  curdir = cd('../../irt'); 
  irtdir = pwd;
  setup(); 
  cd(curdir);
end

% add relevant directories
addpath('../model/spgr/');
addpath('../model/dess/');
addpath('../crb/');
addpath('../etc/');

lincon.tr = 263.7;%(2*3.6 + 4.8) * 9;                      % deoni:11:com time budget at 3.0T = 108

% cost function options
subArg.cost = {...
  'x.ff.minmax', [0.03 0.21],...
  'x.ff.nsamp', 5,...
  'x.T1f.nsamp', 1,...
  'x.T1s.nsamp', 1,...
  'x.T2f.nsamp', 1,...
  'x.T2s.nsamp', 1,...
  'x.kfs.nsamp', 1,...
  'nu.kap.nsamp', 3};
  
% gradient function options
subArg.grad = {...
  'x.ff.minmax', [0.03 0.21],...
  'x.ff.nsamp', 5,...
  'x.T1f.nsamp', 1,...
  'x.T1s.nsamp', 1,...
  'x.T2f.nsamp', 1,...
  'x.T2s.nsamp', 1,...
  'nu.kap.nsamp', 3};

% construct parameter initialization
rng.de.tr = [17.5 Inf];
rng.sp.tr = [11.8 Inf];
rng.de.aex = [1 60] * (pi/180);                       % control energy deposition
rng.sp.aex = [1 40] * (pi/180);                       % narrow range to minimize partial spoiling

% fmincon options
fminconArg = {...
  'boxcon.de.tr', col(rng.de.tr),...
  'boxcon.sp.tr', col(rng.sp.tr),...
  'boxcon.de.aex', col(rng.de.aex),...
  'boxcon.sp.aex', col(rng.sp.aex),...
  'lincon.tr', lincon.tr,...
  'fmincon.tolFun', 1e-7,...
  'fmincon.tolX', 1e-7,...
  'fmincon.alg', 'active-set',...
  'fmincon.disp', 'off',...
  'fmincon.maxIter', 500};

opt.save = 1;

tic;
% stepwise algorithm
maxCde = floor(lincon.tr / rng.de.tr(1));
maxCsp = floor(lincon.tr / rng.sp.tr(1));
queue = cell(1, maxCde * maxCsp);
idx = 1;
tail = 1;
map = zeros(maxCde, maxCsp);
for Cde = 1:maxCde
    for Csp = 1:maxCsp
        if Cde * rng.de.tr(1) + Csp * rng.sp.tr(1) > lincon.tr || Cde * 2 + Csp < 6
            map(Cde, Csp) = NaN;
        end
    end
end

queue{idx}.Cde = 9;
queue{idx}.Csp = 9;
queue{idx}.addDE = 1;
queue{idx}.addSP = 0;
queue{idx}.P.de.tr = rng.de.tr(1) * ones(queue{idx}.Cde,1);
queue{idx}.P.sp.tr = rng.sp.tr(1) * ones(queue{idx}.Csp,1);
% queue{idx}.P.de.aex = col(linspace(randi(60), randi(60), queue{idx}.Cde)) * (pi/180);  
% queue{idx}.P.sp.aex = col(linspace(randi(40), randi(40), queue{idx}.Csp)) * (pi/180);
queue{idx}.P.de.aex = col(linspace(10, 50, queue{idx}.Cde)) * (pi/180);  
queue{idx}.P.sp.aex = col(linspace(10, 30, queue{idx}.Csp)) * (pi/180);

queue{idx}.P = gmj_Popt_wrapper(queue{idx}.P, subArg, fminconArg{:});
queue{idx}.f = dess_spgr_2comp_cost(queue{idx}.P, subArg.cost{:});
map(queue{idx}.Cde, queue{idx}.Csp) = queue{idx}.f;
fopt = queue{idx}.f;
P = queue{idx}.P;

while idx <= tail
    fprintf('\n--------------------Dealing with (%dDE, %dSP) of f = %.6f and rstd = %.4f.---------------\n',...
        queue{idx}.Cde, queue{idx}.Csp, queue{idx}.f, sqrt(queue{idx}.f) ./ mean([0.03 0.21]));
    if fopt > queue{idx}.f
        fopt = queue{idx}.f;
        P = queue{idx}.P;
    end
    fprintf('Until now fopt = %.6f and rstd.opt = %.4f\n', fopt, sqrt(fopt) ./ mean([0.03 0.21]));
    
    % delete one de
    if queue{idx}.Cde > 1 && map(queue{idx}.Cde - 1, queue{idx}.Csp) == 0
        fprintf('Generate (%dDE, %dSP)... \n', queue{idx}.Cde - 1, queue{idx}.Csp);
        tmpfopt = 100000.0;
        for i = 1:queue{idx}.Cde
            fprintf('-->Deleting DE No. %d, ', i);
            tmp.P = queue{idx}.P;
            tmp.P.de.tr(i) = [];
            tmp.P.de.aex(i) = [];
            tmp.P = gmj_Popt_wrapper(tmp.P, subArg, fminconArg{:});
            tmp.f = dess_spgr_2comp_cost(tmp.P, subArg.cost{:});
            if tmpfopt > tmp.f
                tmpfopt = tmp.f;
                tmpP = tmp.P;
            end
            fprintf('generate f = %.6f and rstd = %.4f\n', tmp.f, sqrt(tmp.f) ./ mean([0.03 0.21]));
        end
        tail = tail + 1;
        queue{tail}.Cde = queue{idx}.Cde - 1;
        queue{tail}.Csp = queue{idx}.Csp;
        queue{tail}.addDE = 0;
        queue{tail}.addSP = 1;
        queue{tail}.P = tmpP;
        queue{tail}.f = tmpfopt;
        map(queue{tail}.Cde, queue{tail}.Csp) = queue{tail}.f;
    end
    
    % delete one sp
    if queue{idx}.Csp > 1 && map(queue{idx}.Cde, queue{idx}.Csp - 1) == 0
        fprintf('Generate (%dDE, %dSP)... \n', queue{idx}.Cde, queue{idx}.Csp - 1);
        tmpfopt = 100000.0;
        for i = 1:queue{idx}.Csp
            fprintf('-->Deleting SP No. %d, ', i);
            tmp.P = queue{idx}.P;
            tmp.P.sp.tr(i) = [];
            tmp.P.sp.aex(i) = [];
            tmp.P = gmj_Popt_wrapper(tmp.P, subArg, fminconArg{:});
            tmp.f = dess_spgr_2comp_cost(tmp.P, subArg.cost{:});
            if tmpfopt > tmp.f
                tmpfopt = tmp.f;
                tmpP = tmp.P;
            end
            fprintf('generate f = %.6f and rstd = %.4f\n', tmp.f, sqrt(tmp.f) ./ mean([0.03 0.21]));
        end
        tail = tail + 1;
        queue{tail}.Cde = queue{idx}.Cde;
        queue{tail}.Csp = queue{idx}.Csp - 1;
        queue{tail}.addDE = 1;
        queue{tail}.addSP = 0;
        queue{tail}.P = tmpP;
        queue{tail}.f = tmpfopt;
        map(queue{tail}.Cde, queue{tail}.Csp) = queue{tail}.f;
    end
    
    % add one scan
    % TODO
    
    idx = idx + 1;
end

rstd.opt  = sqrt(fopt) ./ mean([0.03 0.21]);

t = toc;
% print output
fprintf('\nTotal execution time is %0.2f minutes.\n', t/60);
fprintf('Optimized profile (%d, %d) yields mean ff rstd = %0.4f with f = %0.6f.\n',...
    length(P.de.aex), length(P.sp.aex), rstd.opt, fopt);

% save population
if opt.save==1
    tmp = sprintf('stepwise-%.4f', rstd.opt);
    tmp = strrep(tmp, '.', 'p');
    tmp = strcat(tmp, '.mat');
    save(tmp);
end