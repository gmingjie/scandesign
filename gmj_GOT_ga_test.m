% script gmj_GOT_ga_test.m
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

% header options
bool.sv = 1;                                          % save optimized scan design

% construct parameter initialization
rng.de.tr = [17.5 Inf];
rng.sp.tr = [11.8 Inf];
rng.de.aex = [1 60] * (pi/180);                       % control energy deposition
rng.sp.aex = [1 40] * (pi/180);                       % narrow range to minimize partial spoiling

lincon.tr = (2*3.6 + 4.8) * 9;                      % deoni:11:com time budget at 3.0T = 108

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

% boxcon options
boxconArg = {...
  'boxcon.de.tr', col(rng.de.tr),...
  'boxcon.sp.tr', col(rng.sp.tr),...
  'boxcon.de.aex', col(rng.de.aex),...
  'boxcon.sp.aex', col(rng.sp.aex),...
  'lincon.tr', lincon.tr};

% ga optimization options
opt = optimoptions('ga',...
    'Display', 'iter');

% genetic algorithm
C.de = 3; % will double
C.sp = 3;

tic;
[P, fval, flag] = gmj_GOT_ga(C, subArg.cost, boxconArg, opt);                              
t = toc;

% calculate final coefficient of variation w.r.t. mean(ff)
rstd.opt  = sqrt(fval)   ./ mean([0.03 0.21]);

% print output
fprintf('\nTotal execution time is %0.2f minutes.\n', t/60);
fprintf('Optimized profile (%d, %d) yields mean ff rstd = %0.4f with f = %0.6f.\n', Cde, Csp, rstd.opt, fval);

% save design
if bool.sv
  tmp = sprintf('ga_%dde%dsp-%.1f-%.4f', C.de, C.sp, lincon.tr, rstd.opt);
  tmp = strrep(tmp, '.', 'p');
  tmp = strcat(tmp, '.mat');
  save(tmp);
end