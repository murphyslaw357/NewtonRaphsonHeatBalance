clear
clc

foldersource='C:\Users\ctc\Documents\GitHub\NewtonRaphsonHeatBalance\';
%foldersource='/Users/Shaun/Documents/GitHub/NewtonRaphsonHeatBalance/';
%foldersource='/mnt/HA/groups/nieburGrp/Shaun/NewtonRaphsonHeatBalance/';

conductorData=importfileAA(strcat(foldersource,'ConductorInfo.csv'));
[conductorCount,~]=size(conductorData);

conductorData.ResistanceACLowdegc=conductorData.ResistanceDCLowdegc;
conductorData.ResistanceACLowdegcMeter=conductorData.ResistanceACLowdegc./conductorData.MetersperResistanceInterval;
conductorData.ResistanceACHighdegcMeter=conductorData.ResistanceACHighdegc./conductorData.MetersperResistanceInterval;
conductorData.simulated=zeros(conductorCount,1);

Tref=25;
epsilons=0.9;
H=0;
phi=90*pi/180;
sigmab=5.6697e-8;
alphas=0.9;
a=-33:65;
[~,a3]=size(a);
spacer=10;
searchIncrement=0.01;

weatherPermutationCount=a3*(spacer+1)^3;
deltainfo=zeros(weatherPermutationCount,conductorCount);
delta1info=zeros(weatherPermutationCount,conductorCount);
psolinfo=zeros(weatherPermutationCount,conductorCount);
windinfo=zeros(weatherPermutationCount,conductorCount);
ambtempinfo=zeros(weatherPermutationCount,conductorCount);
currentinfo=zeros(weatherPermutationCount,conductorCount);
rootinfo=zeros(weatherPermutationCount,conductorCount);
cinfo=(-1*realmax).*ones(weatherPermutationCount,conductorCount);
stepinfo=zeros(weatherPermutationCount,conductorCount);

for c1=1:12:conductorCount
    for c=3:c1+11
        root=realmax.*ones(weatherPermutationCount,1);
        delta=zeros(weatherPermutationCount,1);
        delta1=zeros(weatherPermutationCount,1);
        psols=zeros(weatherPermutationCount,1);
        winds=zeros(weatherPermutationCount,1);
        ambtemps=zeros(weatherPermutationCount,1);
        currents=zeros(weatherPermutationCount,1);
        cs=(-1*realmax).*ones(weatherPermutationCount,1);
        steps=zeros(weatherPermutationCount,1);
        
        cdata=conductorData(c,:);
        maxcurrent=ceil(1.5*cdata.AllowableAmpacity);
        diam=cdata.DiamCompleteCable*0.0254;
        maxpsol=1050*diam*alphas;

        beta=(cdata.ResistanceACHighdegcMeter-cdata.ResistanceACLowdegcMeter)/(cdata.HighTemp-cdata.LowTemp);
        alpha=cdata.ResistanceACHighdegcMeter-beta*cdata.HighTemp;    
        counter=0;
        for psol=0:maxpsol/spacer:maxpsol
            disp(psol)
            for imagnitude=0:maxcurrent/spacer:maxcurrent
                IIstar=abs(imagnitude)^2; 
                for ambtemp=-33:65
                    %GuessTc2=((psol+IIstar*(alpha+25*beta))/(pi*diam*sigmab*epsilons)+((ambtemp+273)^4))^(1/4)-273; 
                    %GuessTc=(psol+IIstar*(alpha+25*beta))/(pi*diam*sigmab*epsilons*((1.38e8)+ambtemp*(1.39e6))+pi*(2.42e-2)*0.645)+ambtemp;
                    for Vw=0:10/spacer:10
                        GuessTc=GetGuessTemp(imagnitude,ambtemp,H,diam,phi,Vw,alpha,beta,epsilons,psol);
                        counter=counter+1
                        psols(counter)=psol;
                        winds(counter)=Vw;
                        ambtemps(counter)=ambtemp;
                        currents(counter)=imagnitude;
                        [roott,~,~,~,~,~,~] =GetTempNewton(imagnitude,ambtemp,H,diam,phi,Vw,alpha,beta,epsilons,psol);
                        root(counter,1)=roott;
                        rerun=1;
                        reruncounter=0;
                        topend=max(roott,GuessTc);
                        bottomend=min(roott,GuessTc);
                        tempSearch=(bottomend-10:searchIncrement:topend+10)';
                       
                        [searchCount,~]=size(tempSearch);
                        tempSearch=[tempSearch,zeros(searchCount,6)];
                        for i=1:searchCount
                            [Tc,I2R,I2Rprime,Prad,Pradprime,Pcon,Pconprime,A,m,C,n] =GetTempNewtonFirstIteration(imagnitude,ambtemp,H,diam,phi,Vw,alpha,beta,epsilons,psol,tempSearch(i,1));
                            tempSearch(i,2)=Tc;
                            tempSearch(i,3)=A;
                            tempSearch(i,4)=m;
                            tempSearch(i,5)=C;
                            tempSearch(i,6)=n;
                        end
                        while(rerun)
                            rerun=0;
                            reruncounter=reruncounter+1;
                            if(reruncounter>5000)
                                msg='error condition!';
                                error(msg)
                            end
                            
                            searchRes=tempSearch(tempSearch(:,1)>bottomend-delta(counter,1)& tempSearch(:,1)<topend+delta1(counter,1),:);
                            if(max(searchRes(:,2))>topend+delta1(counter,1))
                                delta1(counter,1)=max(searchRes(:,2))-topend;
                                rerun=1;
                            end
                            if(min(searchRes(:,2))<bottomend-delta(counter,1))
                                delta(counter,1)=bottomend-min(searchRes(:,2));
                                rerun=1;
                            end
%                             for Tcc=root(counter,1)-delta(counter,1):0.1:GuessTc+delta1(counter,1)
%                                 [Tc,I2R,I2Rprime,Prad,Pradprime,Pcon,Pconprime] =GetTempNewtonFirstIteration(imagnitude,ambtemp,H,diam,phi,Vw,alpha,beta,epsilons,psol,Tcc);
%                                 if(Tc<root(counter,1)-delta(counter,1))
%                                     delta(counter,1)=root(counter,1)-Tc;
%                                     rerun=1;
%                                 elseif(Tc>GuessTc+delta1(counter,1))
%                                     delta1(counter,1)=Tc-GuessTc;
%                                     rerun=1;
%                                 end
%                                 if(rerun) 
%                                     break 
%                                 end
%                             end
                        end
                        [searchResCount,~]=size(searchRes);
                        if(counter==1090)
                        end
                        if(searchResCount>1)
                            if (all(searchRes(:,3) == searchRes(1,3)) && all(searchRes(:,4) == searchRes(1,4)) && all(searchRes(:,5) == searchRes(1,5)) && all(searchRes(:,6) == searchRes(1,6)))
                                steps(counter)=-1;
                            else
                                steps(counter)=1;
                            end
                            ctemp=-1*realmax*ones(searchResCount,searchResCount);
                            for i=1:searchResCount-1
                                for j=i+1:searchResCount
                                    %disp(strcat(num2str(i),',',num2str(j)));
                                    ctemp(i,j)=abs(searchRes(i,2)-searchRes(j,2))/abs(searchRes(i,1)-searchRes(j,1));
%                                     if(C>cs(counter))
%                                         cs(counter)=C;
%                                         if(C>1)
%                                         end
%                                     end
                                end
                            end
                            cs(counter)=max(max(ctemp));
                         end
%                         for Tcc=roott-delta(counter,1):0.1:GuessTc+delta1(counter,1)-0.1                                                              
%                             [Tc,~,~,~,~,~,~] =GetTempNewtonFirstIteration(imagnitude,ambtemp,H,diam,phi,Vw,alpha,beta,epsilons,psol,Tcc);
%                             for Tcc1=Tcc+0.1:0.1:GuessTc+delta1(counter,1)
%                                 [Tc1,~,~,~,~,~,~] =GetTempNewtonFirstIteration(imagnitude,ambtemp,H,diam,phi,Vw,alpha,beta,epsilons,psol,Tcc1);
%                                 C=abs(Tc-Tc1)/abs(Tcc-Tcc1);
%                                 if(C>1)
%                                     exceptions=[exceptions;c,imagnitude,ambtemp,Vw,psol,roott,GuessTc,GuessTc2,delta(counter,1),delta1(counter,1),Tcc,Tcc1];
%                                 end
%                             end
%                         end
                    end
                end
            end
        end
        %end
        %disp(strcat(num2str(delta(c)),',',num2str(delta1(c)),',',num2str(100*c/conductorCount),',',cellstr(cdata.CodeWord)));
        rootinfo(:,c)=root;
        deltainfo(:,c)=delta;
        delta1info(:,c)=delta1;
        psolinfo(:,c)=psols;
        windinfo(:,c)=winds;
        ambtempinfo(:,c)=ambtemps;
        currentinfo(:,c)=currents;
        cinfo(:,c)=cs;
        stepinfo(:,c)=steps;
    end
    csvwrite(strcat(foldersource,'rootinfo.csv'),rootinfo);
    csvwrite(strcat(foldersource,'deltainfo.csv'),deltainfo);
    csvwrite(strcat(foldersource,'delta1info.csv'),delta1info);
    csvwrite(strcat(foldersource,'psolinfo.csv'),psolinfo);
    csvwrite(strcat(foldersource,'windinfo.csv'),windinfo);
    csvwrite(strcat(foldersource,'ambtempinfo.csv'),ambtempinfo);
    csvwrite(strcat(foldersource,'currentinfo.csv'),currentinfo);
    csvwrite(strcat(foldersource,'cinfo.csv'),cinfo);
    csvwrite(strcat(foldersource,'stepinfo.csv'),stepinfo);
    
    writetable(conductorData,'ConductorValidationResults.csv'); 
end
