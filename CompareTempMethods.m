clear
clc
 
conductorData=importfile('ConductorInfo.csv');
[conductorCount,~]=size(conductorData);
conductorData.Validated=zeros(conductorCount,1);
conductorData.minfirstderivative=zeros(conductorCount,1);
conductorData.ResistanceACLowdegc=conductorData.ResistanceDCLowdegc;
conductorData.ResistanceACLowdegcMeter=conductorData.ResistanceACLowdegc./conductorData.MetersperResistanceInterval;
conductorData.ResistanceACHighdegcMeter=conductorData.ResistanceACHighdegc./conductorData.MetersperResistanceInterval;

Tref=25;
epsilons=0.9;
H=0;
phi=12;
Vw=2;
sigmab=5.6697e-8;
alphas=0.9;
cond=zeros(conductorCount,1);
minFirstDer=zeros(conductorCount,1);
minSecondDer=zeros(conductorCount,1);
maxCurrent=zeros(conductorCount,1);
counters=zeros(conductorCount,1);

spacer=2;


c=61;
%for c1=1:83:conductorCount
    %for c=c1:c1+82
        cdata=conductorData(c,:);
        A=cellstr(cdata.Type);
        cond(c)=1;
        maxcurrent=ceil(1.5*cdata.AllowableAmpacity);
        diam=cdata.DiamCompleteCable*0.0254;
        disp(strcat(num2str(100*c/conductorCount),cellstr(cdata.CodeWord)))
        minFirstDer(c)=-1*realmax;       
        minSecondDer(c)=-1*realmax;
        maxpsol=1050*diam*alphas;
        a1=0:maxpsol/spacer:maxpsol;
        [~,a1num]=size(a1);
        a2=10:(maxcurrent-10)/spacer:maxcurrent;
        [~,a2num]=size(a2);
        a3=-33:65;
        [~,a3num]=size(a3);
        a4=0:0.1:10;
        [~,a4num]=size(a4);
        murphyTemp=zeros(a1num,a2num,a3num,a4num);
        cecchiTemp=zeros(a1num,a2num,a3num,a4num);
        blackTemp=zeros(a1num,a2num,a3num,a4num);
        std738Temp=zeros(a1num,a2num,a3num,a4num);
        
        beta=(cdata.ResistanceACHighdegcMeter-cdata.ResistanceACLowdegcMeter)/(cdata.HighTemp-cdata.LowTemp);
        alpha=cdata.ResistanceACHighdegcMeter-beta*cdata.HighTemp;
        solarcounter=0;
        for psol=0:maxpsol/spacer:maxpsol
            solarcounter=solarcounter+1
            currentcounter=0;
            for imagnitude=10:(maxcurrent-10)/spacer:maxcurrent
                currentcounter=currentcounter+1;
                ambtempcounter=0;
                IIstar=abs(imagnitude)^2; 
                for ambtemp=-33:65
                    ambtempcounter=ambtempcounter+1;
                    windcounter=0;
                    for Vw=0:0.1:10
                        windcounter=windcounter+1;
                         [Tc,~,~,~,~,~,~] =GetTempNewtonFullDiagnostic(imagnitude,ambtemp,H,diam,phi,Vw,cdata.ResistanceACHighdegcMeter,cdata.ResistanceACLowdegcMeter, cdata.HighTemp, cdata.LowTemp,epsilons,psol);
                         murphyTemp(solarcounter,currentcounter,ambtempcounter,windcounter)=Tc;
                         cecchiTemp(solarcounter,currentcounter,ambtempcounter,windcounter)=ambtemp;
                         [Tc] = GetTempBlack(imagnitude,ambtemp,diam,phi,Vw,cdata.ResistanceACHighdegcMeter,cdata.ResistanceACLowdegcMeter, cdata.HighTemp, cdata.LowTemp,epsilons,psol);
                         blackTemp(solarcounter,currentcounter,ambtempcounter,windcounter)=Tc;
                         [Tc] = GetTempStd738(imagnitude,ambtemp,diam,phi,Vw,cdata.ResistanceACHighdegcMeter,cdata.ResistanceACLowdegcMeter, cdata.HighTemp, cdata.LowTemp,epsilons,psol,H);
                         std738Temp(solarcounter,currentcounter,ambtempcounter,windcounter)= Tc;
                    end
                end
            end
        end
    %end
    conductorData.Counters=counters;
    conductorData.Validated=cond;
    conductorData.minfirstderivative=minFirstDer;
    conductorData.minsecondderivative=minSecondDer;
    conductorData.Maxcurrent=maxCurrent;
    writetable(conductorData,'ConductorValidationResults.csv'); 
%end

std738=squeeze(std738Temp(1,a2num,:,:));
murphy=squeeze(murphyTemp(1,a2num,:,:));
cecchi=squeeze(cecchiTemp(1,a2num,:,:));
black=squeeze(blackTemp(1,a2num,:,:));
surf(a4,a3,(std738-murphy))
zlabel('Error - �C')
ylabel('Ambient Temperature')
xlabel('Wind Speed')
figure
surf(a4,a3,(cecchi-murphy))
zlabel('Error - �C')
ylabel('Ambient Temperature')
xlabel('Wind Speed')
figure
surf(a4,a3,(black-murphy))
zlabel('Error - �C')
ylabel('Ambient Temperature')
xlabel('Wind Speed')