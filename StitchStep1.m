clear
clc
close all
conductorInfoTotal=[];

rootFolder = 'C:\Users\ctc\Documents\GitHub\Chapter3\';
folderStart = 'C:\Users\ctc\Documents\GitHub\Chapter3\Step1_PolyTrain\';
% rootFolder = '/Volumes/THESIS/Github/Chapter3/';
% folderStart = '/Volumes/THESIS/Github/Chapter3/Step1_PolyTrain/';

myFiles = dir(fullfile(folderStart,'*.mat'));
for k = 1:length(myFiles)
    load(strcat(folderStart,myFiles(k).name),'cdata')
    conductorInfoTotal = [conductorInfoTotal;cdata];
    disp(k/length(myFiles))
end

conductorInfoTotal=sortrows(conductorInfoTotal,'Index');
conductorInfo = conductorInfoTotal;
save(strcat(rootFolder,'conductorInfoPoly.mat'),'conductorInfo')