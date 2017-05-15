%% init
close all
clear
clc

addpath('../data'); % set path to data

filename = uigetfile;

load(filename);
data = recording;

% values for cue duration 
T_CUE_ON = 3;  
T_CUE    = 2;


%% Chop the data into pieces:
pos     = data.trial;
dataset = data.X;

%% detrend data
detrended_dataset = detrendData(data.X, pos);
filtered_dataset = filterData(detrended_dataset, pos);

dataset = filtered_dataset;

%% move labels to cue location
pos = shiftLabels(pos, T_CUE_ON);

%%
nTrials = data.numTrials;
Fs = data.fs;        % Sampling Frequency.
nPre    = 1*Fs;
nPost   = (T_CUE+1)*Fs-1;
n       = nPre + nPost + 1;
nChannels = 3;


timeSeries          = zeros(3, n, nTrials);
frequencyDomain     = zeros(3, n/2+1, nTrials);
label               = data.y;

class1_idx          = find(label == 1);
class2_idx          = find(label == 2);

%% artifact occurences have not been noted
%samplesWArtifacts   = find(data{1,1}.artifacts);
clean_class1_idx    = class1_idx;
clean_class2_idx    = class2_idx;

%%
for i=1:nTrials
    timeSeries(:,:,i)       = dataset(pos(i)-nPre:pos(i)+nPost,1:3)';
    P2 = abs(fft(timeSeries(:,:,i), n, 2)/n);
    frequencyDomain(:,:,i) = P2(:,1:n/2+1);
    frequencyDomain(:,2:end-1,i) = 2*frequencyDomain(:,2:end-1,i);
    frequencyDomain(:,:,i) = frequencyDomain(:,:,i).^2;
    label = data.y;
end

nClassSamples = 9;
f = Fs * (0:(n/2))/n;
%% plot freq domain
figure
for i=1:1:nClassSamples
    subplot(2,nClassSamples,i)
    plot(f,frequencyDomain(:,:,clean_class1_idx(i))');
end

for i=1:1:nClassSamples
    subplot(2,nClassSamples,nClassSamples+i)
    plot(f, frequencyDomain(:,:,clean_class2_idx(i))');
end

%% Extract Alpha Channel:
lowerAlpha = 7;
upperAlpha = 13;

lowerBeta = 15;
upperBeta = 30; % was : upperBeta = 26

alpha   = intersect(find(f >= lowerAlpha), find(f <= upperAlpha));
beta    = intersect(find(f >= lowerBeta), find(f <= upperBeta));

%%
figure
for i=1:1:nClassSamples
    subplot(2,nClassSamples,i)
    hold on
    plot(f(alpha),frequencyDomain(:,alpha,clean_class1_idx(i))');
    plot(f(beta),frequencyDomain(:,beta,clean_class1_idx(i))');
end

for i=1:1:nClassSamples
    subplot(2,nClassSamples,nClassSamples+i)
    hold on
    plot(f(alpha),frequencyDomain(:,alpha,clean_class2_idx(i))');
    plot(f(beta),frequencyDomain(:,beta,clean_class2_idx(i))');
end


%% Extract the features:
cleanSamples    = union(clean_class1_idx, clean_class2_idx);
cleanFreq       = frequencyDomain(:,:,cleanSamples);
cleanLabels     = label(cleanSamples);

samplesPerHerz  = 6;
maskLength      = n/2+1;
wBand           = [2, 4, 6, 8];
nBand           = [21, 19, 17, 15];

nFeaturesPerChannel = sum(nBand);
channelOffsett      = (0:nChannels-1) * nFeaturesPerChannel;
bandOffset          = [0,cumsum(nBand)];

features        = zeros(nChannels*nFeaturesPerChannel, size(cleanFreq,3));

for trial = 1:size(cleanFreq,3)
    for channel = 1:nChannels
        for i=1:4
            
            mask = [ones(1,wBand(i)*samplesPerHerz), zeros(1,maskLength-wBand(i)*samplesPerHerz)];
            
            for band = 1:nBand(i)
                
                try
                    features((channel-1)*nFeaturesPerChannel + bandOffset(i) + band, trial) = sum(cleanFreq(channel, logical(mask), trial));
                catch
                    a =5;
                end
                mask = circshift(mask, samplesPerHerz);
            end
        end
    end
end

%% Dimensionality Reduction:
[pca_coeff,~,~] = pca(features', 'NumComponents', 12);
redFeatures = pca_coeff' * features;

figure
gscatter(redFeatures(1,:), redFeatures(2,:), cleanLabels,'rb', '.');

%% Classify the samples:
SVMModel = fitcsvm(redFeatures',cleanLabels, ...
    'Standardize',true,             ...
    'KernelFunction','RBF',         ...(from the
    'KernelScale','auto',           ...
    'OptimizeHyperparameters', 'all');

%%
CVSVMModel = crossval(SVMModel);
classLoss = kfoldLoss(CVSVMModel);

filename = ['SVM_',recording.id,'_',num2str(classLoss),'_', recording.date, '.mat'];
save(filename, 'SVMModel', 'pca_coeff');

% for i=1:120
%     min1(i)         = min(D3C4(:,i));
%     mean1(i)        = mean(D3C4(:,i));
%     max1(i)         = max(D3C4(:,i));
%     stdr1(i)        = std(D3C4(:s,i));
%     madian1(i)      = median(D3C4(:,i));
%     bandpower4(i)   = bandpower(D3C4(:,i),250, [18,22]);
%
% end
%
% Vector2=[transpose(min1) transpose(max1) transpose(mean1) transpose(stdr1) transpose(madian1)  transpose(bandpower1) transpose(bandpower2)]
%
% % Calculation The Coificients Vectors
%
% cD3 = detcoef(C,L,3);                   %NOISY
% cD4 = detcoef(C,L,4);                   %NOISY
%
% D31 = wrcoef('d',C,L,waveletFunction,3); %NOISY
% D41 = wrcoef('d',C,L,waveletFunction,4); %NOISY
%
%
% power1=(sum(D31.^2))/length(D31);
% power2=(sum(D41.^2))/length(D41);