clc; close all; 


% Import the data 
sensorData1 = readtable("C:\Users\sham9\OneDrive\Documents\ADAML\project\OneDrive_1_10-09-2026\data_part_1.csv");
sensorData2 = readtable("C:\Users\sham9\OneDrive\Documents\ADAML\project\OneDrive_1_10-09-2026\data_part_2.csv");

X1=table2array(sensorData1(:, 23:1742));
X2=table2array(sensorData2(:, 40:1759));

% Combaining the data
X=[X1; X2];
varNames = "Wavelength" + string(1:size(X,2));


%Find missing values and observation
missingVars = sum(ismissing(X)); [missingVars, idxMissingVars]   = sort(missingVars, 'descend');
missingObs  = sum(ismissing(X,2));  [missingObs, idxMissingObs]     = sort(missingObs, 'descend');


%%
%Center and Scale Data
scale_X = zscore(X);

%%
%Compute PCA

[P, T, latent, explained] = pca(scale_X, 'Centered', false);
%%

%Explained variance by PCs
explVar = cumsum(explained);
%explVar = 100 * cumsum(latent) / cumsum(latent);
figure; 
plot(1:length(explVar), explVar);
xlabel("No. PCs in the model");
ylabel("Explained variance of the model [R^2 value] [%]");
title("Cummulative explained variances by principal components");


%%

figure; i = 1;
biplot(P(:,i:2), 'Scores', T(:,i:2));
xlabel("PC " + string(i) + " R2: " + string(round(explained(i))) + " [%]");
ylabel("PC " + string(i+1) + " R2: " + string(round(explained(i+1))) + " [%]");
%%
%Represent Biplots and Loadings plots
figure; ii = 1;
for i = 1:4
    subplot(2, 4, ii);
    biplot(P(:,i:i+1), 'Scores', T(:,i:i+1));
    xlabel("PC " + string(i)  );
    ylabel("PC " + string(i+1));
    ii = ii + 1;
    
    subplot(2, 4, ii)
    bar(P(:,i));
    title("Loadings of PC " + string(i));
    xlabel("Wavelength index");
    ii = ii + 1;
end

