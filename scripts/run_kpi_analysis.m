%% run_kpi_analysis.m - Model 0 (WSCC01.slx, 110 s, +30 MW at t = 50.0 s)
rootDir = fileparts(fileparts(mfilename('fullpath')));
load_system(fullfile(rootDir, 'models', 'WSCC01.slx'));
simOut = sim('WSCC01');
f_out = simOut.get('f_out'); P_out = simOut.get('P_out');
disp('Model 0 (WSCC01) 110 s simulation complete.');
