if(ispc==1)
    startCond = 1
    endCond = 2
    foldersource='C:\Users\ctc\Documents\GitHub\Chapter3\';
elseif(ismac==1)
    foldersource='/Users/Shaun/Documents/GitHub/Chapter3/';
elseif(isunix==1)
    startCond = str2num(getenv('SGE_TASK_ID'))
    endCond = startCond + 1
    foldersource='/mnt/HA/groups/nieburGrp/Shaun/Chapter3/';
end

load(strcat(foldersource,'GrPrSpline.mat'))
load(strcat(foldersource,'ReNuSpline.mat'))
load(strcat(foldersource,'NuReSpline.mat'))
%% Load conductor info
load(strcat(foldersource,'conductorInfoPoly.mat'))
%conductorData=importfileAB(strcat(foldersource,'conductorData.csv'));
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
conductorInfo.lowestRise = zeros(conductorCount,1);
conductorInfo.lilBottomEnd = zeros(conductorCount,1);
conductorInfo.lilTopEnd = zeros(conductorCount,1);
%% Setup weather data
epsilons=0.9;
H=0;
phi=90*pi/180;
maxpsol=1050;
alphas=0.9;
spacer=10;
searchIncrement=0.001;
weatherPermutationCount=(spacer+1)^4;

psols=zeros(weatherPermutationCount,1);
winds=zeros(weatherPermutationCount,1);
ambtemps=zeros(weatherPermutationCount,1);
currents=zeros(weatherPermutationCount,1);

counter=0;
for imagnitude=0.005:(0.05)/(spacer*2):0.055
    for psol=0:maxpsol/spacer:maxpsol
        for ambtemp=-33:98/spacer:65
            for Vw=0:10/spacer:10
                counter=counter+1;
                psols(counter)=psol*alphas;
                winds(counter)=Vw;
                ambtemps(counter)=ambtemp;
                currents(counter)=imagnitude;
            end
        end
    end
end

%% Run conductor simulation 
if endCond>conductorCount
    endCond=conductorCount;
end
for c=startCond:endCond
    disp(c)
    if(conductorInfo(c,:).polymodels==""||conductorInfo(c,:).simulated==1)
        continue;
    end
    cdata=conductorInfo(c,:);  
%     delta=zeros(weatherPermutationCount,1);
%     delta1=zeros(weatherPermutationCount,1);
    cs=zeros(weatherPermutationCount,1);

    maxcurrent=ceil(cdata.AllowableAmpacity);
    diam=cdata.DiamCompleteCable*0.0254;
    beta=(cdata.ResistanceACHighdegcMeter-...
        cdata.ResistanceACLowdegcMeter)/(cdata.HighTemp-cdata.LowTemp);
    alpha=cdata.ResistanceACHighdegcMeter-beta*cdata.HighTemp;  
    polymodel=str2func(conductorInfo(c,:).polymodels);
    for counter=1:weatherPermutationCount
        if(currents(counter)<=conductorInfo(c,:).convergeCurrent) %+0.0001
            continue;
        end
        GuessTc=GetGuessTemp(currents(counter)*maxcurrent,...
            ambtemps(counter),diam,phi,winds(counter),alpha,beta,...
            epsilons,psols(counter),polymodel);       
        [roott,~,~,~,~,~,~] = GetTempNewton(currents(counter)*...
            maxcurrent,ambtemps(counter),H,diam,phi,winds(counter),...
            alpha,beta,epsilons,psols(counter),f,ff,ffinv,polymodel);
        [convergenceOrder] = GetTempNewtonGetCC(currents(counter)*...
            maxcurrent,ambtemps(counter),H,diam,phi,winds(counter),...
            alpha,beta,epsilons,psols(counter),f,ff,ffinv,polymodel,roott);

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
                winds(counter),alpha,beta,epsilons,psols(counter),...
                temps,f,ff,ffinv);

            h=I2R+psols(counter)*diam*alphas-Pcon-Prad;
            hprime=I2Rprime-PconPrime-PradPrime;
            hprimeprime=-1*PconPrimePrime-PradPrimePrime;

            bigSearch=horzcat(temps,Tc,abs((h.*hprimeprime)./(hprime.^2)));
            
            searchRes=bigSearch(bigSearch(:,1)>=lilBottomEnd & ...
            bigSearch(:,1)<= lilTopEnd,:);
            if(max(searchRes(:,2))>bigTopEnd || (min(searchRes(:,2))<bigBottomEnd && min(searchRes(:,2))>ambtemps(counter)))
                msg='error condition: temp iteration excursion';
                error(msg)
            end
            if(min(searchRes(:,2))<=ambtemps(counter))
                conductorInfo(c,:).convergeCurrent=currents(counter);
                disp(strcat('Convergence current too low: ',num2str(currents(counter))))
                break
            end
            if(max(searchRes(:,2))>lilTopEnd)
                lilTopEnd=max(searchRes(:,2));
                rerun=1;
            end
            if(min(searchRes(:,2))<lilBottomEnd)
                lilBottomEnd=min(searchRes(:,2));
                rerun=1;
            end
        end
        
        cs(counter)=max(searchRes(:,3));
        if(cs(counter)>1) %&& ...
                %currents(counter)>conductorInfo(c,:).convergeCurrent)
            conductorInfo(c,:).convergeCurrent=currents(counter);
            disp(strcat('Convergence current too low: ',num2str(currents(counter))))
        end
        if(cs(counter)>1 && (roott-ambtemps(counter))>...
                conductorInfo(c,:).lowestRise)
            conductorInfo(c,:).lowestRise=(roott-ambtemps(counter));
            disp(strcat('Minimum conductor rise updated: ',num2str(roott-ambtemps(counter))))
        end
    end
    conductorInfo(c,:).lilBottomEnd=lilBottomEnd;
    conductorInfo(c,:).lilTopEnd=lilTopEnd;
    conductorInfo(c,:).Cmax=max(cs);
    conductorInfo(c,:).Cmin=min(cs(cs~=0));
    conductorInfo(c,:).simulated=1;
end
conductorInfo = conductorInfo(startCond:endCond,:);
conductorInfo.Index = (startCond:endCond)';

save(strcat(foldersource,'Chapter3_July2020',num2str(startCond),'matlab.mat'))