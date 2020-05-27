clear
clc
close all

if(ispc==1)
    foldersource='C:\Users\ctc\Documents\GitHub\Chapter3\';
elseif(ismac==1)
    foldersource='/Users/Shaun/Documents/GitHub/Chapter3/';
elseif(isunix==1)
    foldersource='/mnt/HA/groups/nieburGrp/Shaun/Chapter3/';
end

conductorDataTotal=[];

folderStart = 'C:\Users\ctc\Documents\GitHub\Chapter3\May2020';
myFiles = dir(fullfile(folderStart,'*.mat'));
for k = 1:length(myFiles)
    load(strcat(folderStart,'\',myFiles(k).name),'conductorData')
    conductorDataTotal = [conductorDataTotal;conductorData];
    disp(k/length(myFiles))
%   baseFileName = myFiles(k).name;
%   fullFileName = fullfile(myFolder, baseFileName);
%   fprintf(1, 'Now reading %s\n', fullFileName);
%   [wavData, Fs] = wavread(fullFileName);
%   % all of your actions for filtering and plotting go here
end

conductorDataTotal=sortrows(conductorDataTotal,'Index');

[conductorCount,~] = size(conductorDataTotal);

diff=0.05/20;
convergeLimit=conductorDataTotal.convergeCurrent+diff;
figure('Renderer', 'painters', 'Position', [10 10 500 300]);
plot(convergeLimit.*100)
ylim([0 5])
hold on
yL = get(gca,'YLim');
line([68 68],yL,'LineStyle','--','Color','r');
line([132 132],yL,'LineStyle','--','Color','r');
line([161 161],yL,'LineStyle','--','Color','r');
line([175 175],yL,'LineStyle','--','Color','r');
line([230 230],yL,'LineStyle','--','Color','r');
line([302 302],yL,'LineStyle','--','Color','r');
line([339 339],yL,'LineStyle','--','Color','r');
xlabel('Conductor Index')
ylabel('Minimum Convergence Current (%)')

set(gca,'FontSize',10)

% savefig(strcat(foldersource,'Figure3_1.fig'))
set(gcf, 'Color', 'w');

if(ispc)
    export_fig C:\Users\ctc\Documents\GitHub\Chapter3\Figure3_1.png -m3
elseif(ismac)
    export_fig /Volumes/THESIS/Github/Chapter3/Figure3_1.png -m3
end

%fig = gcf;
%fig.PaperPositionMode = 'auto';
%print(gcf,strcat(foldersource,'Figure3_1.jpg'),'-r1200','-djpeg')

% saveas(gcf,strcat(foldersource,'Figure3_1.jpg'))