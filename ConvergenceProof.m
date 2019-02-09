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
weatherPermutationCount=a3*(spacer+1)^3;
deltainfo=zeros(weatherPermutationCount,conductorCount);
delta1info=zeros(weatherPermutationCount,conductorCount);
rootinfo=zeros(weatherPermutationCount,conductorCount+4);

for c1=1:10:conductorCount
    for c=c1:c1+9
        root=realmax.*ones(weatherPermutationCount,1);
        delta=2.*ones(weatherPermutationCount,1);
        delta1=2.*ones(weatherPermutationCount,1);
        cdata=conductorData(c,:);
        maxcurrent=ceil(1.5*cdata.AllowableAmpacity);
        diam=cdata.DiamCompleteCable*0.0254;
        maxpsol=1050*diam*alphas;

        beta=(cdata.ResistanceACHighdegcMeter-cdata.ResistanceACLowdegcMeter)/(cdata.HighTemp-cdata.LowTemp);
        alpha=cdata.ResistanceACHighdegcMeter-beta*cdata.HighTemp;    
        counter=0;
        for psol=0:maxpsol/spacer:maxpsol
            disp(psol)
            for imagnitude=0:(maxcurrent)/spacer:maxcurrent
                disp(imagnitude)
                IIstar=abs(imagnitude)^2; 
                for ambtemp=-33:65
                    GuessTc=((psol+IIstar*(alpha+25*beta))/(pi*diam*sigmab*epsilons)+((ambtemp+273)^4))^(1/4)-273; 
                    for Vw=0:10/spacer:10
                        counter=counter+1;
                        %if(root(counter,1)==realmax)
                            [roott,~,~,~,~,~,~] =GetTempNewton(imagnitude,ambtemp,H,diam,phi,Vw,alpha,beta,epsilons,psol);
                            root(counter,1)=roott;
                        %end
                        rerun=1;
                        reruncounter=0;
                        while(rerun)
                            rerun=0;
                            reruncounter=reruncounter+1;
                            if(reruncounter>500)
                            end

                            for Tcc=root(counter,1)-delta(counter,1):0.1:GuessTc+delta1(counter,1)
                                %fcounter=fcounter+1;
                                [Tc,I2R,I2Rprime,Prad,Pradprime,Pcon,Pconprime] =GetTempNewtonFirstIteration(imagnitude,ambtemp,H,diam,phi,Vw,alpha,beta,epsilons,psol,Tcc);
                                h=I2R+psol-Prad-Pcon;
                                hprime=I2Rprime-Pradprime-Pconprime;
                                g=Tcc-h/hprime;
                                if(g<ambtemp)
                                end
                                %pcontracker(fcounter)=Pcon;
                                %pconprimetracker(fcounter)=Pconprime;
                                %ftracker(fcounter)=h;
                                %fprimetracker(fcounter)=hprime;
                                %temp(fcounter)=Tcc;
                                if(g<root(counter,1)-delta(counter,1))
                                    delta(counter,1)=0.1+root(counter,1)-g;
                                    rerun=1;
                                elseif(g>GuessTc+delta1(counter,1))
                                    delta1(counter,1)=0.1+g-GuessTc;
                                    rerun=1;
                                end
                                if(rerun) 
                                    break 
                                end
                            end
                        end
                     end
                end
            end
        end
        %end
        %disp(strcat(num2str(delta(c)),',',num2str(delta1(c)),',',num2str(100*c/conductorCount),',',cellstr(cdata.CodeWord)));
        rootinfo(:,c)=root;
        deltainfo(:,c)=delta;
        delta1info(:,c)=delta1;
        %conductorData.simulated(c)=1;
    %     conductorData.delta=delta;
    %     conductorData.delta1=delta1;

        %writetable(rootinfo,'rootinfo.csv'); 
    end

    csvwrite('deltainfo.csv',deltainfo);
    csvwrite('delta1info.csv',delta1info);
    writetable(conductorData,'ConductorValidationResults.csv'); 

end
