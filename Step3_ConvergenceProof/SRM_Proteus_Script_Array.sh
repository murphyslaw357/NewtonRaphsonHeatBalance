#!/bin/bash
#$ -S /bin/bash
#$ -m beas
#$ -j y
#$ -cwd
#$ -P nieburPrj
#$ -pe shm 16
#$ -l h_rt=8:00:00
#$ -l h_vmem=4G
#$ -l matlab=1

. /etc/profile.d/modules.sh
module load shared
module load sge/univa
module load proteus
module load matlab
cd '/mnt/HA/groups/nieburGrp/Shaun/Chapter3/Step2_ConvergenceProof'

matlab -nodisplay -nodesktop -nosplash -noFigureWindows -r "run ConvergenceProofFn.m"