clear
clc
close all

if(ispc==1)
    startCond = 1
    endCond = 415
    foldersource='C:\Users\ctc\Documents\GitHub\Chapter3\';
elseif(ismac==1)
    startCond = 1
    endCond = 132
    foldersource='/Volumes/THESIS/GitHub/Chapter3/';
elseif(isunix==1)
    startCond = str2num(getenv('SGE_TASK_ID'))
    foldersource='/lustre/scratch/srm329/Chapter3/';
end

%% Load conductor info
load(strcat(foldersource,'conductorInfoStep2Indv/conductorInfoStep2_',num2str(startCond),'.mat'))

[conductorCount,~]=size(cdata);
cdata.ResistanceACLowdegc=cdata.ResistanceDCLowdegc;
cdata.simulated=zeros(conductorCount,1);
cdata.Cmax=zeros(conductorCount,1);
cdata.Cmin=zeros(conductorCount,1);
cdata.guessMAPE = zeros(conductorCount,1);
cdata.guessMIN = zeros(conductorCount,1);
cdata.guessMAX = zeros(conductorCount,1);
cdata.guessMEAN = zeros(conductorCount,1);
cdata.guessSTD = zeros(conductorCount,1);
cdata.fPrimeCheck = zeros(conductorCount,1);
%% Setup weather data
epsilons=0.9;
H=0;
phi=90*pi/180;
maxpsol=1050;
alphas=0.9;
spacer=15;
 
psols=0:maxpsol/spacer:maxpsol;
winds=0:10/spacer:10;
ambtemps=-33:98/spacer:65;
% currents=[1.5:-0.005:0.02, 0.019:-0.001:0.002];
currents=[1.5:-0.005:0.005, 0.00499:-0.00001:0.00001];
inputCombo = allcomb(currents,psols,winds,ambtemps);
currents=inputCombo(:,1);
psols=inputCombo(:,2);
winds=inputCombo(:,3);
ambtemps=inputCombo(:,4);
weatherPermutationCount = size(inputCombo,1);

%% Run conductor simulation 
% if endCond>conductorCount
%     endCond=conductorCount;
% end
% for c=endCond:-1:startCond
%     if(~isfile(strcat(foldersource,'Step3_ConvergenceProof/',num2str(startCond),'matlab.mat')))
%         disp(c)
%         cdata=conductorInfo(c,:);  
        rootts = ones(weatherPermutationCount,1);
        maxcurrent=ceil(cdata.AllowableAmpacity);
        diam=cdata.DiamCompleteCable*0.0254;
        beta=(cdata.ResistanceACHighdegcMeter-...
            cdata.ResistanceACLowdegcMeter)/(cdata.HighTemp-cdata.LowTemp);
        alpha=cdata.ResistanceACHighdegcMeter-beta*cdata.HighTemp;  
        polymodel=str2func(cdata.polymodels);
        GuessTcs=GetGuessTemp(currents.*maxcurrent,ambtemps,diam,phi,winds,...
            alpha,beta,alphas,psols,polymodel); 
        iterationData = zeros(weatherPermutationCount,4);
        cmax=zeros(weatherPermutationCount,1);
        fullRun=zeros(weatherPermutationCount,1);
        fPrimeCheck=zeros(weatherPermutationCount,1);
        fPrimeAvg=zeros(weatherPermutationCount,1);
        fPrimePrimeAvg=zeros(weatherPermutationCount,1);
        failTcRise=-realmax.*ones(weatherPermutationCount,1);
        sim=0;
        tic
        minrise=cdata.minGuessRise;
        for bigStep=1:5000:weatherPermutationCount
            endStep=bigStep+4999;
            if(endStep>weatherPermutationCount)
                endStep=weatherPermutationCount;
            end
            disp(bigStep)
            toc
            for counter=bigStep:endStep
    %             if(mod(counter,5000)==0)
    %                 toc
    %                 disp(strcat(num2str(counter/weatherPermutationCount),'_',num2str(counter)))
    %             end
                GuessTc=GuessTcs(counter);
                currentCounter = currents(counter)*maxcurrent;
                ambtempCounter = ambtemps(counter);
                windCounter = winds(counter);
                psolCounter = psols(counter);
                GuessTcRise=GuessTc-ambtemps(counter);
                if(GuessTcRise<=cdata.minGuessRise)
                    continue;
                end

                [roott,~,~,~,~,~,~] = GetTempNewton(currentCounter,...
                    ambtempCounter,H,diam,phi,windCounter,...
                    alpha,beta,epsilons,alphas,psolCounter,GuessTc);
                if(isnan(roott))
                    cdata.minGuessRise=nan;
                    break;
                end
                rootts(counter)=roott;
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
%                         msg='error condition: rerun counter exceeded limit';
%                         error(msg)
                        cdata.minGuessRise=nan;
                        break;
                    end

                    searchIncrement = (lilTopEnd-lilBottomEnd)/50;
                    temps=[(bigBottomEnd:searchIncrement:bigTopEnd)'; lilTopEnd; lilBottomEnd];
                    temps(temps<=ambtemps(counter))=[];
                    searchCount=size(temps,1);

                    [~,~,~,~,~,~,~,~,~,~,~,~,A,m,Cinv,ninv,C,n]=GetTempNewtonFirstIteration(...
                            currentCounter,ambtempCounter,H,diam,phi,...
                            windCounter,alpha,beta,epsilons,alphas,psolCounter,...
                            GuessTc,[]);
                    AmCinvninvCn = [A,m,Cinv,ninv,C,n];

                    [Tc,I2R,I2Rprime,Prad,PradPrime,PradPrimePrime,Pcon,PconPrime,...
                        PconPrimePrime,~,~,~,~,~,~,~,~,~] =GetTempNewtonFirstIteration2(...
                        currentCounter,ambtempCounter,H,diam,phi,...
                        windCounter,alpha,beta,epsilons,alphas,psolCounter,...
                        temps,AmCinvninvCn);

                    h=I2R+psols(counter)*diam*alphas-Pcon-Prad;
                    hprime=I2Rprime-PconPrime-PradPrime;
                    hprimeprime=-1*PconPrimePrime-PradPrimePrime;

                    bigSearch=horzcat(temps,Tc,abs((h.*hprimeprime)./(hprime.^2)),hprime);

                    searchRes=bigSearch(bigSearch(:,1)>=lilBottomEnd & ...
                    bigSearch(:,1)<= lilTopEnd,:);
                    if(max(searchRes(:,2))>bigTopEnd)
                        bigTopEnd = max(searchRes(:,2))+10;
                        rerun=1;
                    end
                    if(min(searchRes(:,2))<bigBottomEnd && min(searchRes(:,2))>ambtemps(counter))
                        bigBottomEnd = max([ambtemps(counter),min(searchRes(:,2))-10]);
                        rerun=1;
                    end
                    if(min(searchRes(:,2))<=ambtemps(counter))
                        failTcRise(counter)=GuessTcRise;
                        disp(strcat('Convergence current too low - update to less than Ta: ',num2str(currents(counter))))
                        sim=sim+1000;
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
    %                     if(GuessTcRise>cdata.minGuessRise)
                            failTcRise(counter)=GuessTcRise;
    %                         cdata.minGuessRise=GuessTcRise;
    %                     end
                        disp(strcat('Guess Trise too low - |c|>1: ',num2str(GuessTcRise)))
                        sim=sim+1;
                        break
                    end
                end
                if(isnan(cdata.minGuessRise))
                    break
                end
                iterationData(counter,:)=[bigTopEnd,bigBottomEnd,lilBottomEnd,lilTopEnd];
                if(all(searchRes(:,4)<0)) 
                    fPrimeCheck(counter)=-1;
                elseif (all(searchRes(:,4)>0))
                    fPrimeCheck(counter)=1;
                end
                fullRun(counter)=1;
                cmax(counter)=max(searchRes(:,3));
            end
            if(isnan(cdata.minGuessRise))
                break
            end
         end
         if(~isnan(cdata.minGuessRise))
             if(all(fPrimeCheck(fullRun==1)))
                 cdata.fPrimeCheck=1;
             elseif(all(fPrimeCheck(fullRun==-1)))
                 cdata.fPrimeCheck=-1;
             end
             guessErr=GuessTcs(fullRun==1)-rootts(fullRun==1);
             cdata.guessMIN=min(guessErr);
             cdata.guessMAX=max(guessErr);
             cdata.guessMEAN=mean(guessErr);
             cdata.guessSTD=std(guessErr);
             cdata.guessMAPE=mean(abs((guessErr)./(rootts(fullRun==1)+273)));
             cdata.Cmax=max(cmax(fullRun==1));
             cdata.Cmin=min(cmax(fullRun==1));
             cdata.simulated=sim;
             cdata.minGuessRise=max([1.25*failTcRise; cdata.minGuessRise]);
         end
         save(strcat(foldersource,'Step3_ConvergenceProof/',num2str(startCond),'matlab.mat'),'cdata');
%      end
% end