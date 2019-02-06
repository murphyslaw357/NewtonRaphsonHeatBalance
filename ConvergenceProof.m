clear
clc

conductorData=importfileAA('C:\Users\ctc\Documents\GitHub\NewtonRaphsonHeatBalance\ConductorInfo.csv');
[conductorCount,~]=size(conductorData);
conductorData.ResistanceACLowdegc=conductorData.ResistanceDCLowdegc;
conductorData.ResistanceACLowdegcMeter=conductorData.ResistanceACLowdegc./conductorData.MetersperResistanceInterval;
conductorData.ResistanceACHighdegcMeter=conductorData.ResistanceACHighdegc./conductorData.MetersperResistanceInterval;

Tref=25;
epsilons=0.9;
H=0;
phi=90;
sigmab=5.6697e-8;
alphas=0.9;
spacer=10;
deltas=zeros(conductorCount,1);
delta1s=zeros(conductorCount,1);
Cs=zeros(conductorCount,1);
for c=1:conductorCount
    cdata=conductorData(c,:);
    maxcurrent=ceil(1.5*cdata.AllowableAmpacity);
    diam=cdata.DiamCompleteCable*0.0254;
    disp(strcat(num2str(100*c/conductorCount),cellstr(cdata.CodeWord)))
    maxpsol=1050*diam*alphas;

    beta=(cdata.ResistanceACHighdegcMeter-cdata.ResistanceACLowdegcMeter)/(cdata.HighTemp-cdata.LowTemp);
    alpha=cdata.ResistanceACHighdegcMeter-beta*cdata.HighTemp;
    a=0:maxpsol/spacer:maxpsol;
    [~,a1]=size(a);
    a=10:(maxcurrent-10)/spacer:maxcurrent;
    [~,a2]=size(a);
    a=-33:65;
    [~,a3]=size(a);
    limits=zeros(a1*a2*a2,3);
    counter=0;
    rerun=1;
    delta=100;
    delta1=100;
    Cs(c)=-1*realmax;
    while(rerun)
        rerun=0;
        for psol=0:maxpsol/spacer:maxpsol
            for imagnitude=10:(maxcurrent-10)/spacer:maxcurrent
                IIstar=abs(imagnitude)^2; 
                for ambtemp=-33:65
                    GuessTc=((psol+IIstar*(alpha+25*beta))/(pi*diam*sigmab*epsilons)+((ambtemp+273)^4))^(1/4)-273; 
                    %for Vw=0:0.1:10
                         Vw=10;
                         phi=90*pi/180;
                         [root,~,~,~,~,~,~] =GetTempNewtonFullDiagnostic(imagnitude,ambtemp,H,diam,phi,Vw,alpha,beta,epsilons,psol);
                         counter=counter+1;
                         dist=ceil((GuessTc+delta1)-(root-delta));
                         ftracker=zeros(dist,1);
                         fprimetracker=zeros(dist,1);
                         pcontracker=zeros(dist,1);
                         pconprimetracker=zeros(dist,1);
                         temp=zeros(dist,1);
                         fcounter=0;
                         for Tcc=root-delta:GuessTc+delta1
                             fcounter=fcounter+1;
                            [Tc,I2R,I2Rprime,Prad,Pradprime,Pradprimeprime,Pcon,Pconprime,Pconprimeprime] =GetTempNewtonFullDiagnosticFirstIteration(imagnitude,ambtemp,H,diam,phi,Vw,alpha,beta,epsilons,psol,Tcc);
                            h=I2R+psol-Prad-Pcon;
                            hprime=I2Rprime-Pradprime-Pconprime;
                            hprimeprime=-1*Pradprimeprime-Pconprimeprime;
                            pcontracker(fcounter)=Pcon;
                            pconprimetracker(fcounter)=Pconprime;
                            ftracker(fcounter)=h;
                            fprimetracker(fcounter)=hprime;
                            temp(fcounter)=Tcc;
                            gprime=abs(1-((hprime*hprime-h*hprimeprime)/(hprime^2)));
                            g=Tcc-h/hprime;
                            if(g<root-delta)
                                delta=root-g;
                                rerun=1;
                            elseif(g>GuessTc+delta1)
                                delta1=g-GuessTc;
                                rerun=1;
                            end
                            if(rerun) 
                                break 
                            end
                            if(gprime>Cs(c))
                                Cs(c)=gprime;
                            end
                         end
                         if(dist>20)
%                             disp('') 
                         end
                     %end
                     if(rerun)
                         break
                     end
                end
                 if(rerun)
                     break
                 end
            end
            if(rerun)
                break
            end
        end
    end
    deltas(c)=delta;
    delta1s(c)=delta1;
    disp(delta)
    disp(delta1)    
end
conductorData.deltas=deltas;
conductorData.delta1s=delta1s;
conductorData.Cs=Cs;
writetable(conductorData,'ConductorValidationResults.csv'); 