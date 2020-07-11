clear
clc
close all

if(ispc==1)
    startCond = 132
    endCond = 132
    foldersource='C:\Users\ctc\Documents\GitHub\Chapter3\';
elseif(ismac==1)
    foldersource='/Users/Shaun/Documents/GitHub/Chapter3/';
elseif(isunix==1)
    startCond = str2num(getenv('SGE_TASK_ID'))
    endCond = startCond
    foldersource='/mnt/HA/groups/nieburGrp/Shaun/Chapter3/';
end

load(strcat(foldersource,'GrPrSpline.mat'))
load(strcat(foldersource,'ReNuSpline.mat'))
load(strcat(foldersource,'NuReSpline.mat'))
%% Load conductor info
load(strcat(foldersource,'conductorInfoPoly.mat'))

[conductorCount,~]=size(conductorInfo);
conductorInfo.ResistanceACLowdegc=conductorInfo.ResistanceDCLowdegc;
conductorInfo.ResistanceACLowdegcMeter=...
    conductorInfo.ResistanceACLowdegc./...
    conductorInfo.MetersperResistanceInterval;
conductorInfo.ResistanceACHighdegcMeter=...
    conductorInfo.ResistanceACHighdegc./...
    conductorInfo.MetersperResistanceInterval;
conductorInfo.simulated=zeros(conductorCount,1);
conductorInfo.convergenceOrder=realmax.*ones(conductorCount,1);
conductorInfo.Cmax=zeros(conductorCount,1);
conductorInfo.Cmin=zeros(conductorCount,1);
conductorInfo.convergeCurrent = zeros(conductorCount,1);
conductorInfo.lowestRise = realmax.*ones(conductorCount,1);
conductorInfo.lilBottomEnd = zeros(conductorCount,1);
conductorInfo.lilTopEnd = zeros(conductorCount,1);
conductorInfo.guessMAPE = zeros(conductorCount,1);
conductorInfo.guessMIN = zeros(conductorCount,1);
conductorInfo.guessMAX = zeros(conductorCount,1);
conductorInfo.guessMEAN = zeros(conductorCount,1);
conductorInfo.guessSTD = zeros(conductorCount,1);
%% Setup weather data
epsilons=0.9;
H=0;
phi=90*pi/180;
maxpsol=1050;
alphas=0.9;
spacer=10;

psols=0:maxpsol/spacer:maxpsol;
winds=0:10/spacer:10;
ambtemps=-33:98/spacer:65;
currents=[1.5:-0.01:0.02, 0.019:-0.001:0.002];
inputCombo = allcomb(currents,psols,winds,ambtemps);
currents=inputCombo(:,1);
psols=inputCombo(:,2);
winds=inputCombo(:,3);
ambtemps=inputCombo(:,4);

weatherPermutationCount = size(inputCombo,1);

%% Run conductor simulation 
if endCond>conductorCount
    endCond=conductorCount;
end
for c=startCond:endCond
    disp(c)
    cdata=conductorInfo(c,:);  
    output = zeros(weatherPermutationCount,4);
    maxcurrent=ceil(cdata.AllowableAmpacity);
    diam=cdata.DiamCompleteCable*0.0254;
    beta=(cdata.ResistanceACHighdegcMeter-...
        cdata.ResistanceACLowdegcMeter)/(cdata.HighTemp-cdata.LowTemp);
    alpha=cdata.ResistanceACHighdegcMeter-beta*cdata.HighTemp;  
    polymodel=str2func(cdata.polymodels);
    GuessTcs=GetGuessTemp(currents.*maxcurrent,ambtemps,diam,phi,winds,...
        alpha,beta,epsilons,alphas,psols,polymodel); 
    if(any(c==[75,111,113,190,254,257,262,288]))
        polymodel1=str2func(conductorInfo(c-1,:).polymodels);
        GuessTcs1=GetGuessTemp(currents.*maxcurrent,ambtemps,diam,phi,winds,...
            alpha,beta,epsilons,alphas,psols,polymodel1);
        polymodel2=str2func(conductorInfo(c+1,:).polymodels);
        GuessTcs2=GetGuessTemp(currents.*maxcurrent,ambtemps,diam,phi,winds,...
            alpha,beta,epsilons,alphas,psols,polymodel2);
        GuessTcs=(GuessTcs1+GuessTcs2)./2;
        disp('avg_fn')
    end
    output(:,1)=GuessTcs;
    I2Rs = zeros(weatherPermutationCount,1);
    Prads = zeros(weatherPermutationCount,1);
    Pcons = zeros(weatherPermutationCount,1);
    cmin=zeros(weatherPermutationCount,1);
    cmax=zeros(weatherPermutationCount,1);
    tic
    for counter=1:weatherPermutationCount
        if(mod(counter,10000)==0)
            toc
            disp(strcat(num2str(counter/weatherPermutationCount),'_',num2str(counter)))
        end
        if(currents(counter)<=conductorInfo(c,:).convergeCurrent)
            continue;
        end
        
        GuessTc=GuessTcs(counter);

        [roott,I2R,~,Prad,~,Pcon,~] = GetTempNewton(currents(counter)*...
            maxcurrent,ambtemps(counter),H,diam,phi,winds(counter),...
            alpha,beta,epsilons,alphas,psols(counter),f,ff,ffinv,GuessTc);
        I2Rs(counter)=I2R;
        Prads(counter)=Prad;
        Pcons(counter)=Pcon;
        output(counter,2)=roott;
        
        [convergenceOrder] = GetTempNewtonGetCC(currents(counter)*...
            maxcurrent,ambtemps(counter),H,diam,phi,winds(counter),...
            alpha,beta,epsilons,alphas,psols(counter),f,ff,ffinv,GuessTc,roott);
 
        if(convergenceOrder<conductorInfo(c,:).convergenceOrder)
            conductorInfo(c,:).convergenceOrder=convergenceOrder;
        end
        
        lilTopEnd=max(roott,GuessTc)+0.05;
        lilBottomEnd=min(roott,GuessTc);
        bigTopEnd=lilTopEnd+10;
        bigBottomEnd=lilBottomEnd-10;
        rerun=1;
        reruncounter=0;
        
        while(rerun)
            rerun=0;
            reruncounter=reruncounter+1;

            if(reruncounter>5000)
                msg='error condition: rerun counter exceeded limit';
                error(msg)
            end
            
            searchIncrement = (lilTopEnd-lilBottomEnd)/50;
            temps=[(bigBottomEnd:searchIncrement:bigTopEnd)'; lilTopEnd; lilBottomEnd];
            temps(temps<=ambtemps(counter))=[];
            searchCount=size(temps,1);

            [Tc,I2R,I2Rprime,Prad,PradPrime,PradPrimePrime,Pcon,PconPrime,...
                PconPrimePrime,~,~,~] =GetTempNewtonFirstIteration2(...
                currents(counter)*maxcurrent,ambtemps(counter),H,diam,phi,...
                winds(counter),alpha,beta,epsilons,alphas,psols(counter),...
                temps,f,ff,ffinv);

            h=I2R+psols(counter)*diam*alphas-Pcon-Prad;
            hprime=I2Rprime-PconPrime-PradPrime;
            hprimeprime=-1*PconPrimePrime-PradPrimePrime;

            bigSearch=horzcat(temps,Tc,abs((h.*hprimeprime)./(hprime.^2)));
            
            searchRes=bigSearch(bigSearch(:,1)>=lilBottomEnd & ...
            bigSearch(:,1)<= lilTopEnd,:);
            if(max(searchRes(:,2))>bigTopEnd)
                bigTopEnd = max(searchRes(:,2))+10;
                rerun=1;
                %msg='error condition: temp iteration excursion';
                %error(msg)
            end
            if(min(searchRes(:,2))<bigBottomEnd && min(searchRes(:,2))>ambtemps(counter))
                bigBottomEnd = max([ambtemps(counter),min(searchRes(:,2))-10]);
                rerun=1;
                %msg='error condition: temp iteration excursion';
                %error(msg)
            end
            if(min(searchRes(:,2))<=ambtemps(counter))
                if currents(counter)> conductorInfo(c,:).convergeCurrent
                    conductorInfo(c,:).convergeCurrent=currents(counter);
                end
                disp(strcat('Convergence current too low - update to less than Ta: ',num2str(currents(counter))))
                break
            end
            if(max(searchRes(:,2))>lilTopEnd)
                lilTopEnd=max(searchRes(:,2))+0.05;
                rerun=1;
            end
            if(min(searchRes(:,2))<lilBottomEnd)
                lilBottomEnd=min(searchRes(:,2));
                rerun=1;
            end
            if(max(searchRes(:,3))>1)
                if currents(counter)> conductorInfo(c,:).convergeCurrent
                    conductorInfo(c,:).convergeCurrent=currents(counter);
                end
                disp(strcat('Convergence current too low - based on |c|: ',num2str(currents(counter))))
                break
            end
        end
        cmin(counter)=min(searchRes(:,3));
        cmax(counter)=max(searchRes(:,3));
%         if(roott-ambtemps(counter) < conductorInfo(c,:).lowestRise)
%             conductorInfo(c,:).lowestRise=roott-ambtemps(counter);
%             disp(strcat('Minimum conductor rise updated: ',num2str(roott-ambtemps(counter))))
%         end
    end
    conductorInfo(c,:).convergeCurrent=min(currents(currents>conductorInfo(c,:).convergeCurrent));
    output=output(currents>conductorInfo(c,:).convergeCurrent,:);
    output(:,3)=output(:,2)-ambtemps(currents>conductorInfo(c,:).convergeCurrent);
    guessErr = output(:,2)-output(:,1);
    output(:,4)=(output(:,2)-output(:,1))./output(:,2);
    
    conductorInfo(c,:).guessMIN=min(guessErr);
    conductorInfo(c,:).guessMAX=max(guessErr);
    conductorInfo(c,:).guessMEAN=mean(guessErr);
    conductorInfo(c,:).guessSTD=std(guessErr);
    conductorInfo(c,:).guessMAPE=mean(abs(output(:,4)));
    
    conductorInfo(c,:).lowestRise=min(output(output(:,3)~=0,3));
    conductorInfo(c,:).Cmax=max(cmax(currents>conductorInfo(c,:).convergeCurrent));
    conductorInfo(c,:).Cmin=min(cmin(cmin~=0 & currents>conductorInfo(c,:).convergeCurrent));
    conductorInfo(c,:).simulated=1;
end
conductorInfo = conductorInfo(startCond:endCond,:);
conductorInfo.Index = (startCond:endCond)';

save(strcat(foldersource,'Step2_ConvergenceProof/',num2str(startCond),'matlab.mat'))