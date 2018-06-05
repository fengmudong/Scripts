#!/bin/bash

#########
# Script to do RIGID scan on a dihedral angle from 0 to 360 with AMBER. 
# Adapted from a relaxed scan script https://github.com/swails/JmsScripts/blob/master/scan.sh.
#########

# User set Variables

NUM_STEPS=72         # Number of points in PES scan (increment is 360/NUM_STEPS degrees)

PRMTOP="strip.r6.prmtop"      # The name of the topology file for the system

# Remove data from previous runs
rm Dih.dat Etot.dat Edih.dat  
rm -r Restrts Mdinfos Mdouts
mkdir -p Restrts
mkdir -p Mdinfos
mkdir -p Mdouts


increment=`echo "360 / $NUM_STEPS" | bc`


# The following input file means only do energy evaluation, no minimization nor MD. It's in vaccum.

cat > energy.in << EOF
Energy evaluation only
 &cntrl
  imin=1,
  maxcyc=1,
  ntb=0,
  igb=0,
  ntpr=1,
  cut=999,
 /
EOF


for x in `seq 0 1 $NUM_STEPS`; do

    dihedral=`echo "$x * $increment" | bc`

    # The following cpptraj script generates initial structures each has different dihedral value.
    # You should modify manually the line start with trajin and with makestructure.

    cat > run.traj << EOF
    parm $PRMTOP
    trajin s1r6_3.mdcrd 216643 216643
    makestructure cent:1:C3:C6:C17:C13:${dihedral}
    trajout run.rst restart nobox
    run
    quit
EOF

    cpptraj -i run.traj
    sander -O -i energy.in -o mdout.$x.scan -p $PRMTOP -c run.rst -r rst

    mv rst Restrts/rst.$x
    mv mdinfo Mdinfos/mdinfo.$x
    mv mdout.$x.scan Mdouts/
    
    echo $dihedral >> Dih.dat
done


# Post-process the data

# Rename one-digit filenames to two-digit so that subsequent analysis goes in order.
for x in `seq 0 1 9`; do
cd Mdinfos
mv mdinfo.$x mdinfo.0$x
cd ../
done

# Parse mdinfo files into "rigidscan.dat". You should check whether the code is picking out the fields you desiqre.

cd Mdinfos

for file in mdinfo*; do
    head -4 $file | tail -1 | awk '{print $2}' >> ../Etot.dat
    head -6 $file | tail -1 | awk '{print $9}' >> ../Edih.dat
done


cd ../

# You should now plot Dih.dat, Etot.dat, Edih.dat in Jupyter or something.
