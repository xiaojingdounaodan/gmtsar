#!/bin/csh -f
#       $Id$
#
#  D. Sandwell FEB 4 2010
#  M. Wei MAY 4 2010 - ENVISAT
# 
# Align a slave image to a master image and check results
#
alias rm 'rm -f'
unset noclobber
#
# check the number of arguments 
# 
  if ($#argv < 2) then 
    echo ""
    echo "Usage: align_ALOS2_SCAN.csh master_name slave_name [supermaster_name]"
    echo ""
    echo " The supermaster_namestem is required if this is secondary alignment."
    echo ""
    echo "Example: align_ALOS2_SCAN.csh IMG-HH-ALPSRP055750660-H1.0__A IMG-HH-ALPSRP049040660-H1.0__A "
    echo ""
    exit 1
  endif
#
# focus the master if necessary
# Do it no matter what for now. Put SLC_file to PRM. Might not be necessary
#
  if(! -f $1.SLC) then
    ln -s ../../raw/$1.SLC . 
    cp ../../raw/$1.PRM .
    update_PRM.csh $1.PRM SLC_file $1.SLC
  endif
#
# focus the slave image
#
# check the range sampling rate 
# 
  set rng_samp_rate_m = `grep rng_samp_rate $1.PRM | awk 'NR == 1 {printf("%d", $3)}'`
  set rng_samp_rate_s = `grep rng_samp_rate $2.PRM | awk 'NR == 1 {printf("%d", $3)}'`
  if ($rng_samp_rate_m != $rng_samp_rate_s) then 
    echo "The range sampling rate for master and slave differ"
    echo "Need to run the interferogram in steps until process2pass.csh is fixed"
    exit 1
  endif 
  echo "align.csh"
  if(! -f $2.SLC) then
    ln -s ../../raw/$2.SLC .
    cp ../../raw/$2.PRM .
    update_PRM.csh $2.PRM SLC_file $2.SLC
  endif
#
# get the starting alignment parameters and run xcorr
#
  cp $1.PRM $1.PRM0
  cp $2.PRM $2.PRM0
  if($#argv == 3) then
    set RSHIFT = `SAT_baseline $3.PRM $2.PRM | grep rshift | awk '{print $3}'`
    set ASHIFT = `SAT_baseline $3.PRM $2.PRM | grep ashift | awk '{print $3}'`
#
#   use the PRF of the supermaster in the surrogate master
#
    set PRF = `grep PRF $3.PRM | awk '{print $3}'`
    update_PRM.csh $1.PRM PRM $PRF
  else
    set RSHIFT = `SAT_baseline $1.PRM $2.PRM | grep rshift | awk '{print $3}'`
    set ASHIFT = `SAT_baseline $1.PRM $2.PRM | grep ashift | awk '{print $3}'`
  endif
  update_PRM.csh $2.PRM rshift $RSHIFT
  update_PRM.csh $2.PRM ashift $ASHIFT
  echo "align.csh"
  echo "correlate master and slave to find offset parameters"
  xcorr $1.PRM $2.PRM -xsearch 32 -ysearch 256 -nx 32 -ny 128
#
  mv $2.PRM junk.PRM
  cp $1.PRM0 $1.PRM
  grep -v shift < junk.PRM > $2.PRM
#
# put in the alignment parameters 
#
  awk '{print $4}' < freq_xcorr.dat > tmp.dat
  set amedian = `sort -n tmp.dat | awk ' { a[i++]=$1; } END { print a[int(i/2)]; }'`
  set amax = `echo $amedian | awk '{print $1+3}'`
  set amin = `echo $amedian | awk '{print $1-3}'`
  awk '{if($4 > '$amin' && $4 < '$amax') print $0}' < freq_xcorr.dat > tmp2.dat

  fitoffset.csh 2 3 tmp2.dat 10 >> $2.PRM 
  mv freq_xcorr.dat xcorr_$1_$2.dat0
#
# refocus the second image
#
  echo "resamp slave"
  resamp $1.PRM $2.PRM $2.PRMresamp $2.SLCresamp 4
  rm $2.SLC
  mv $2.SLCresamp $2.SLC
  cp $2.PRMresamp $2.PRM

#
rm junk*
#done
