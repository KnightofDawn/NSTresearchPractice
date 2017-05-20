function class_res = classifyWithSVM(X, SVMModel, pca_coeff)

%% init
% values for cue duration 
T_CUE_ON = 3;  
T_CUE    = 2;
pos = 1;



%% Chop the data into pieces:
pos = 1;
% pos     = 4*8*200+1;
dataset = X;

%% detrend data
detrended_dataset = detrendData(dataset, pos);
filtered_dataset = filterData(detrended_dataset, pos);

%% normalize and scale data
X_data_mean = mean(filtered_dataset);
X_data_std = std(filtered_dataset);
X_data_norm = bsxfun(@rdivide, filtered_dataset, X_data_std);


%% DEBUG copy dataset 
dataset = X_data_norm;
% dataset = filtered_dataset;

%% move labels to cue location
pos = shiftLabels(pos, T_CUE_ON);

%%
nTrials = 1;
Fs = 200;        % Sampling Frequency.
nPre    = 1*Fs;
nPost   = (T_CUE+1)*Fs-1;
n       = nPre + nPost + 1;
nChannels = 3;


timeSeries          = zeros(3, n, nTrials);
frequencyDomain     = zeros(3, n/2+1, nTrials);

%%
for i=1:nTrials
    timeSeries(:,:,i)       = dataset(pos(i)-nPre:pos(i)+nPost,1:3)';
    P2 = abs(fft(timeSeries(:,:,i), n, 2)/n);
    frequencyDomain(:,:,i) = P2(:,1:n/2+1);
    frequencyDomain(:,2:end-1,i) = 2*frequencyDomain(:,2:end-1,i);
    frequencyDomain(:,:,i) = frequencyDomain(:,:,i).^2;
end

nClassSamples = 9;
f = Fs * (0:(n/2))/n;

%% Extract Alpha Channel:
lowerAlpha = 7;
upperAlpha = 13;

lowerBeta = 15;
upperBeta = 30; % was : upperBeta = 26

alpha   = intersect(find(f >= lowerAlpha), find(f <= upperAlpha));
beta    = intersect(find(f >= lowerBeta), find(f <= upperBeta));


%% Extract the features:
cleanSamples    = 1;
cleanFreq       = frequencyDomain(:,:,cleanSamples);
% cleanLabels     = label(cleanSamples);

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
redFeatures = pca_coeff' * features;

%% predict class
class_res = predict(SVMModel, redFeatures');

end