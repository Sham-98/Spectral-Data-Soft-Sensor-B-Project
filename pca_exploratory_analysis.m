%% Data Import and Challenges - Items 2 & 3
% Group: Spectral Soft Sensor (B) - Puneet Sharma, Sham Asaad Alkhateb, Arno Törö
% Chosen 5 traits: Anthocyanin, Boron, Ca, EWT, Fiber

clear; clc; close all;

%% 1. Read header row and numeric data SEPARATELY (item 2, 0.25p)
% Why: with ~1740 mostly-numeric column headers (wavelengths), readtable's
% automatic name/type detection becomes unreliable and can silently rename
% columns to generic 'Var1', 'Var2', etc. Reading the header as plain text
% (readcell) and the data body as a plain numeric matrix (readmatrix)
% avoids that problem entirely - no column-name guessing involved.
%
% IMPORTANT: we read the data FIRST to get its true column count, then
% force the header read to match that exact width. Reading the header via
% Range '1:1' alone can silently return one column fewer than the data
% (Excel's "used range" for row 1 doesn't always match the full sheet
% width), which would otherwise misalign every column name by one.

data1full = readmatrix('data_part_1.xlsx', 'Sheet', 'in', 'NumHeaderLines', 1);
headerRow1 = readcell('data_part_1.xlsx', 'Sheet', 'in', 'Range', [1 1 1 size(data1full,2)]);
data1 = data1full(:, 2:end);   % drop the leading row-index column (data)
headerRow1(1) = [];            % drop the leading row-index column (header)

data2full = readmatrix('data_part_2.xlsx', 'Sheet', 'in', 'NumHeaderLines', 1);
headerRow2 = readcell('data_part_2.xlsx', 'Sheet', 'in', 'Range', [1 1 1 size(data2full,2)]);
data2 = data2full(:, 2:end);
headerRow2(1) = [];

fprintf('Part 1: %d rows x %d columns (after dropping index column)\n', size(data1,1), size(data1,2));
fprintf('Part 2: %d rows x %d columns (after dropping index column)\n', size(data2,1), size(data2,2));

% Sanity check - header count MUST equal data column count, or something
% is still misaligned and must not be trusted.
assert(numel(headerRow1) == size(data1,2), 'Part 1: header/data column count mismatch!');
assert(numel(headerRow2) == size(data2,2), 'Part 2: header/data column count mismatch!');
fprintf('Header/data column counts verified to match for both files.\n');

%% 2. Separate wavelength (numeric header) vs trait (text header) columns
% This is the key robustness trick: readcell preserves each header cell's
% TRUE type (numeric vs text), so isnumeric() reliably tells wavelength
% columns (e.g. 400, 401...) apart from trait columns (e.g. "EWT (mg/cm2)"),
% with no string-parsing or encoding guesswork needed.
isWavelength1 = cellfun(@isnumeric, headerRow1);
traitNames1 = headerRow1(~isWavelength1);
traitData1 = data1(:, ~isWavelength1);
wavelengthVals1 = cell2mat(headerRow1(isWavelength1));
X1 = data1(:, isWavelength1);

isWavelength2 = cellfun(@isnumeric, headerRow2);
traitNames2 = headerRow2(~isWavelength2);
traitData2 = data2(:, ~isWavelength2);
wavelengthVals2 = cell2mat(headerRow2(isWavelength2));
X2 = data2(:, isWavelength2);

fprintf('\nPart 1: %d trait columns, %d wavelength columns\n', numel(traitNames1), numel(wavelengthVals1));
fprintf('Part 2: %d trait columns, %d wavelength columns\n', numel(traitNames2), numel(wavelengthVals2));

%% 3. ITEM 3 (0.5p): Identify data challenges

% Challenge A - inconsistent schema between the two source files
extraInPart2 = setdiff(traitNames2, traitNames1);
fprintf('\n[Challenge] Trait columns present ONLY in Part 2: %d\n', numel(extraInPart2));
disp(extraInPart2');
% Part 2 contains extra "concentration" (mg/g) trait columns that Part 1
% does not have. Both files share the same 20 "content" trait columns,
% which is what lets us combine them (see below).

% Challenge B - confirm both files use the same wavelength grid before combining
if isequal(wavelengthVals1, wavelengthVals2)
    fprintf('\nWavelength grids match exactly between files (%d points, %.0f-%.0f nm).\n', ...
        numel(wavelengthVals1), min(wavelengthVals1), max(wavelengthVals1));
    Xcombined = [X1; X2];
    wavelengthVals = wavelengthVals1;
else
    error('Wavelength grids differ between files - manual alignment would be needed.');
end

% Combine on the shared trait columns only (by exact name match)
[sharedNames, ia1, ia2] = intersect(traitNames1, traitNames2, 'stable');
traitDataCombined = [traitData1(:, ia1); traitData2(:, ia2)];

fprintf('\nCombined dataset: %d observations, %d shared trait columns, %d wavelength columns\n', ...
    size(Xcombined,1), numel(sharedNames), numel(wavelengthVals));

% Challenge C - non-unique row indices
% Each file's original first column was just a within-file row counter
% (already dropped above) - it cannot be used to align rows between the
% two files, so they must be treated as two independent sample sets.

% Challenge D - missing data in our 5 chosen traits
chosenKeywords = {'Anthocyanin', 'Boron', 'Ca ', 'EWT', 'Fiber'};
fprintf('\n[Challenge] Missing data in chosen traits (n = %d combined samples):\n', size(traitDataCombined,1));
for i = 1:numel(chosenKeywords)
    colIdx = find(startsWith(sharedNames, chosenKeywords{i}), 1);
    if isempty(colIdx)
        warning('Could not find a trait starting with "%s" - check sharedNames.', chosenKeywords{i});
        continue;
    end
    nAvail = sum(~isnan(traitDataCombined(:, colIdx)));
    fprintf('  %-35s %5d available (%.1f%%)\n', sharedNames{colIdx}, nAvail, 100*nAvail/size(traitDataCombined,1));
end
% Anthocyanin stands out sharply: only ~5% of samples have a value, versus
% 30-38% for the other four chosen traits - a real, quantified example of
% the "missing values in data" challenge, and it will need to be handled
% explicitly later (e.g. a much smaller train/test split for that model).

% Challenge E - spectral matrix itself has no missing data
fprintf('\n[Challenge check] Missing values in spectral matrix Xcombined: %d\n', sum(isnan(Xcombined(:))));
% Unlike the trait columns, the predictor (spectral) matrix is fully
% complete for every sample - missingness is entirely a response-side issue.

% Challenge F - not a time series
% Samples are independent, single-timepoint leaf/canopy measurements
% pooled from many studies and locations - no temporal synchronization
% is needed or applicable.

fprintf('\nTotal combined observations available for modelling: %d\n', size(Xcombined,1));

%% ================= ITEM 5 (3p): PCA Exploratory Analysis on X only =================
% Note: this section only uses Xcombined (the spectral matrix). We are NOT
% looking at the trait/response variables here, per the assignment.

%% 5a. Run PCA (MATLAB's pca() automatically mean-centers the data)
% NOTE: MATLAB's built-in pca() needs the Statistics and Machine Learning
% Toolbox, which isn't installed here. PCA and SVD are mathematically the
% same operation (the same connection from your SVD exercise earlier this
% term) - so we compute PCA manually via SVD instead, using only base
% MATLAB, with identical results to what pca() would have given.
mu = mean(Xcombined, 1);              % column means, for centering
Xc = Xcombined - mu;                  % mean-centered data (PCA requires this)

[U, S, V] = svd(Xc, 'econ');          % economy SVD - same function as before

coeff = V;                            % loadings (variables x components)
score = U * S;                        % scores (samples x components)
eigenvalues = diag(S).^2 / (size(Xc,1) - 1);
explained = eigenvalues / sum(eigenvalues) * 100;   % variance explained, in %

fprintf('\n--- PCA variance explained ---\n');
for i = 1:5
    fprintf('PC%d: %.2f%% (cumulative: %.2f%%)\n', i, explained(i), sum(explained(1:i)));
end

%% 5b. Score plot / "biplot" - PC1 vs PC2, one point per SAMPLE
% This shows how samples relate to each other: clusters, trends, outliers.
% We color by source file (Part 1 vs Part 2) since we already know from
% Item 3 that the two files come from different study subsets - this lets
% us see directly whether that difference shows up in the spectra too.
nPart1 = size(X1, 1);
sourceLabel = [repmat({'Part 1'}, nPart1, 1); repmat({'Part 2'}, size(Xcombined,1) - nPart1, 1)];

figure;
% gscatter() also needs the Statistics and Machine Learning Toolbox -
% same fix as before: plot each group manually with plain scatter().
isPart1 = strcmp(sourceLabel, 'Part 1');
scatter(score(isPart1,1), score(isPart1,2), 15, 'b', 'filled', 'MarkerFaceAlpha', 0.3); hold on;
scatter(score(~isPart1,1), score(~isPart1,2), 15, 'r', 'filled', 'MarkerFaceAlpha', 0.3);
legend('Part 1', 'Part 2');
xlabel(sprintf('PC1 (%.1f%% variance)', explained(1)));
ylabel(sprintf('PC2 (%.1f%% variance)', explained(2)));
title('PCA Score Plot (PC1 vs PC2), colored by source file');
grid on;

%% 5c. Loading plots - which wavelengths drive PC1, PC2, PC3
% This is the standard way to visualize PCA loadings for spectral data
% (a classic arrow-biplot is impractical with 1,721 variables).
figure;
plot(wavelengthVals, coeff(:,1), 'b', 'LineWidth', 1.3); hold on;
plot(wavelengthVals, coeff(:,2), 'r', 'LineWidth', 1.3);
plot(wavelengthVals, coeff(:,3), 'g', 'LineWidth', 1.3);
xlabel('Wavelength (nm)');
ylabel('Loading value');
legend('PC1', 'PC2', 'PC3', 'Location', 'best');
title('PCA Loadings vs Wavelength');
grid on;

%% 5d. Classic biplot (variable arrows), using a sparse subset of
% wavelengths so the arrows stay readable
% biplot() also needs the Statistics and Machine Learning Toolbox - draw
% the variable arrows manually instead (quiver, base MATLAB graphics).
arrowIdx = 1:60:numel(wavelengthVals);   % every 60th wavelength as a labeled arrow
arrowScale = max(abs(score(1:200,1:2)), [], 'all') / max(abs(coeff(arrowIdx,1:2)), [], 'all');

figure;
scatter(score(1:200,1), score(1:200,2), 12, [0.6 0.6 0.6], 'filled'); hold on;
quiver(zeros(numel(arrowIdx),1), zeros(numel(arrowIdx),1), ...
    coeff(arrowIdx,1)*arrowScale, coeff(arrowIdx,2)*arrowScale, 0, 'r', 'LineWidth', 1);
for i = 1:numel(arrowIdx)
    text(coeff(arrowIdx(i),1)*arrowScale, coeff(arrowIdx(i),2)*arrowScale, ...
        string(round(wavelengthVals(arrowIdx(i)))), 'FontSize', 7, 'Color', 'r');
end
xlabel('PC1'); ylabel('PC2');
title('Biplot (PC1 vs PC2), sampled wavelength arrows, first 200 samples shown');

%% 5e. Variable correlation check - adjacent wavelengths are highly correlated
% Spectral data is inherently smooth, so neighboring wavelengths carry
% very similar information (multicollinearity). This is exactly why PCA
% is useful here: it compresses that redundancy into a few components.
% corr() also needs the Statistics and Machine Learning Toolbox - use
% base MATLAB's corrcoef() instead (same result, needs complete rows).
sparseIdx = 1:100:numel(wavelengthVals);   % subsample for a readable heatmap
XsubForCorr = Xcombined(:, sparseIdx);
XsubForCorr = XsubForCorr(all(~isnan(XsubForCorr), 2), :);   % drop any incomplete rows
corrSubset = corrcoef(XsubForCorr);

figure;
imagesc(corrSubset);
colorbar;
clim([-1 1]);
xlabel('Wavelength index (subsampled)');
ylabel('Wavelength index (subsampled)');
title('Correlation matrix of a wavelength subset');

fprintf('\nPCA exploratory analysis complete.\n');
