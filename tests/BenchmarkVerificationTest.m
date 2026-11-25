classdef BenchmarkVerificationTest < matlab.unittest.TestCase
    methods (Test)
        function testScenarioCSVSchemaAndStability(testCase)
            [T, ~] = wscc9.loadBenchmarkData();
            testCase.verifyEqual(height(T), 16);
            reqCols = ["Scenario","Model","Status","RoCoF_500ms_Hz_s","Delta_f_max_Hz","Damping_zeta"];
            testCase.verifyTrue(all(ismember(reqCols, string(T.Properties.VariableNames))));

            stableRows = T(T.Status == "Stable", :);
            testCase.verifyEqual(height(stableRows), 14);
            testCase.verifyTrue(all(isfinite(stableRows.RoCoF_500ms_Hz_s)));
            testCase.verifyTrue(all(isfinite(stableRows.Damping_zeta)));

            unstableRows = T(T.Status ~= "Stable", :);
            testCase.verifyEqual(height(unstableRows), 2);
            testCase.verifyTrue(all(contains(unstableRows.Model, "Model 1")));
        end

        function testSensitivitySweepIntegrity(testCase)
            [~, S] = wscc9.loadBenchmarkData();
            testCase.verifyEqual(height(S), 32);
            testCase.verifyGreaterThanOrEqual(width(S), 4);
        end

        function testPlotAll10KPIsRunsCleanly(testCase)
            tmpPng = [tempname, '.png'];
            cleanup = onCleanup(@() deleteIfExists(tmpPng));
            fig = wscc9.plotAll10KPIs(tmpPng, 'off');
            close(fig);
            testCase.verifyTrue(isfile(tmpPng));
        end
    end
end

function deleteIfExists(f)
if isfile(f), delete(f); end
end