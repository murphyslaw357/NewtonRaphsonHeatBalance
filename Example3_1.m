clear
clc
close all

if(ispc==1)
    foldersource='C:\Users\ctc\Documents\GitHub\Chapter3\';
    addpath(genpath(strcat(foldersource,'Step3_ConvergenceProof\')))
elseif(ismac==1)
    foldersource='/Users/Shaun/Documents/GitHub/Chapter3/';
end

load(strcat(foldersource,'conductorInfoPoly.mat'))

I=1800/2;
Ta=21;
H=0;
D=0.029591;
phi=pi/2;
Vw=4;
alpha=5.3686e-5;
beta=2.6843e-7;
epsilons=0.7;
alphas=0.9;
Psol=1000;
polymodel=str2func(conductorInfo(51,:).polymodels);
GuessTc=GetGuessTemp(I,Ta,D,phi,Vw,...
        alpha,beta,alphas,Psol,polymodel); 
[GuessTc,I2R,I2Rprime,Prad,PradPrime,Pcon,PconPrime] = ...
    GetTempNewton(I,Ta,H,D,phi,Vw,alpha,beta,epsilons,alphas,Psol,GuessTc)