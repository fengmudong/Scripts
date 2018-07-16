#!/bin/bash

#########
# Script to do relaxed scan on a dihedral angle from 0 to 360 with AMBER. 
# Adapted from https://github.com/swails/JmsScripts/blob/master/scan.sh.
#########

# User set Variables

NUM_STEPS=72

prmtop="strip.r6.prmtop"
inpcrd="pucker_30.rst"      # Some initial coordinate file (it will be changed in each scan step. Maybe backup your original one.)

atom1=4 # Four atoms that define the dihedral that you wish to scan
atom2=7
atom3=18
atom4=14


# Remove data from previous runs and make new directories

rm -r Restrts Jarlogs Mdinfos Mdins Mdouts RSTFiles
mkdir -p Restrts
mkdir -p Jarlogs
mkdir -p Mdinfos
mkdir -p Mdins
mkdir -p Mdouts
mkdir -p RSTFiles

increment=`echo "360 / $NUM_STEPS" | bc`

for x in `seq 0 1 $NUM_STEPS`; do

    dihedral=`echo "$x * $increment" | bc`
    
    left=`echo "$dihedral - 100" | bc`   # It's the transition point between linear and quadratic restrain potential.
    right=`echo "$dihedral + 100" | bc`


# Don't indent codes like the following, which contains "EOF". 
cat > dihedral.$x.RST << EOF
torsion restraint for step $x in scan
&rst iat=${atom1},${atom2},${atom3},${atom4} r1=${left}, r2=${dihedral}, r3=${dihedral}, r4=${right}, rk2=5000., rk3=5000., /
EOF

# Vaccum minimization
cat > mdin.$x.scan << EOF
Minimization with a restraint
&cntrl
        imin=1,
        cut=999,
        maxcyc=1000,
        ncyc=50,
        drms=1E-6,
        nmropt=1,
        igb=0,
        ntb=0,
        cut=1000,
/
&wt type='DUMPFREQ', istep1=10 /
&wt type='END'   /
DISANG=dihedral.${x}.RST
LISTIN=POUT
LISTOUT=POUT
DUMPAVE=jar.${x}.log
EOF

sander -O -i mdin.$x.scan -o mdout.$x.scan -p $prmtop -c $inpcrd -r restrt

cp restrt $inpcrd
mv restrt Restrts/restrt.$x
mv mdinfo Mdinfos/mdinfo.$x
mv mdout.$x.scan Mdouts/
mv mdin.$x.scan Mdins/
mv jar.$x.log Jarlogs/
mv dihedral.$x.RST RSTFiles/

done


# Post-process the data

# Rename one-digit filenames to two-digit so that subsequent analysis goes in order.
for x in `seq 0 1 9`; do
cd Mdinfos
mv mdinfo.$x mdinfo.0$x
cd ../Jarlogs
mv jar.$x.log jar.0$x.log
cd ../
done

# Parse the output files and create a file called "profile.dat" which is the desired data file

cd Jarlogs/
tail -n 1 jar* | awk '$1=="==>" {getline;print $2}' > angles.dat
cd ../Mdinfos
grep EAMBER mdinfo* | awk '{print $4}' > energies.dat
cd ../
mv Jarlogs/angles.dat Mdinfos/energies.dat .
paste -d" " angles.dat energies.dat > profile.dat




# You should now plot in Jupyter or something.
