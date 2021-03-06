#!/bin/sh
#
# set -x

# few tinderbox statistics
#

# all active|run'ing images
#
function list_images() {
  (
    ls -1d ~/run/* | xargs -n 1 readlink | sed "s,^..,/home/tinderbox,g" | while read d; do [[ -d $d ]] && echo "$d"; done
    df -h | grep '/home/tinderbox/img./' | cut -f4-5 -d'/' | sed "s,^,/home/tinderbox/,g"
  ) | sort -u -k 5 -t'/'
}


# n is the minimum length to distinguish abbreviated image names
#
function PrintImageName()  {
  n=29
  string="$(basename $i | cut -c1-$n)"
  printf "%-${n}s" $string
}


# gives sth. like:
#
# compl fail   day   todo locked stopping
#  3735   41   3.6  16369                   run/13.0-no-multilib_20170315-195201
#  6956   75   9.6  13285      y            run/13.0-systemd_20170309-190652
#  2904   29   2.5  17220      y           img2/13.0-systemd-libressl_20170316-210316
#
function Overall() {
  echo "compl fail   day   todo locked stopping"
  for i in $images
  do
    log=$i/var/log/emerge.log
    compl=0
    fail=0
    day=0
    if [[ -f $log ]]; then
      compl=$(grep -c '::: completed emerge' $log)
      day=$(echo "scale=1; ($(tail -n1 $log | cut -c1-10) - $(head -n1 $log | cut -c1-10)) / 86400" | bc)
    fi
    # count failed packages based on their version, but not every failed attempt
    # directory name is eg.: 20170417-082345_app-misc_fsniper-1.3.1-r2
    #
    if [[ -d $i/tmp/issues ]]; then
      fail=$(ls -1 $i/tmp/issues | xargs -n 1 basename 2>/dev/null | cut -f2- -d'_' | sort -u | wc -w)
    fi
    todo=$(wc -l < $i/tmp/packages 2>/dev/null)
    [[ -f $i/tmp/LOCK ]] && lck="y" || lck=""
    [[ -f $i/tmp/STOP ]] && stp="y" || stp=""
    d=$(basename $(dirname $i))
    b=$(basename $i)
    [[ -e ~/run/$b ]] && d="run"

    printf "%5i %4i  %4.1f  %5i %6s %8s %5s/%s\n" $compl $fail $day $todo "$lck" "$stp" "$d" "$b"
  done
}


# gives sth. like:
#
# 13.0-abi32+64_20170216-202818              0:13 min  >>> (5 of 8) dev-perl/Email-MessageID-1.406.0
# desktop_20170218-203252                   71:51 min  >>> (1 of 1) games-emulation/sdlmame-0.174
# desktop-libressl-abi32+64_20170215-18565   0:32 min  *** dev-ruby/stringex
#
function LastEmergeOperation()  {
  for i in $images
  do
    PrintImageName
    log=$i/var/log/emerge.log
    if [[ ! -f $log || ! -f $i/tmp/LOCK ]]; then
      echo
      continue
    fi

    # we've to catch the always *latest* emerge task
    # although we'll not display all of them (eg. no *** ... messages)
    #
    tac $log |\
    grep -m 1 -E -e '(>>>|\*\*\*) emerge' -e ' \*\*\* terminating.' -e '::: completed emerge' |\
    sed -e 's/ \-\-.* / /g' -e 's, to /,,g' -e 's/ emerge / /g' -e 's/ completed / /g' -e 's/ \*\*\* .*/ /g' |\
    perl -wane '
      chop ($F[0]);

      my $diff = time() - $F[0];
      my $mm = $diff / 60;
      my $ss = $diff % 60 % 60;

      printf (" %3i:%02i min  %s\n", $mm, $ss, join (" ", @F[1..$#F]));
    '
  done
}


# gives sth. like:
#
# gnome-systemd_20170301-222559     793 1092  696  315
# plasma-abi32+64_20170216-195507   454 1002  839  672 1111 864 691  719 665 469 521 487 460 403  453 388 248
# plasma-abi32+64_20170228-094845   627  462 1111  718  546 182
#
function PackagesPerDay() {
  for i in $images
  do
    PrintImageName
    log=$i/var/log/emerge.log
    if [[ ! -f $log ]]; then
      echo
      continue
    fi

    # qlop gives sth like: Fri Aug 19 13:43:15 2016 >>> app-portage/cpuid2cpuflags-1
    #
    grep '::: completed emerge' $log |\
    cut -f1 -d ':' |\
    perl -wane '
      BEGIN { @p = (0); $first = 0; }
      {
        $cur = $F[0];
        $first = $cur if ($first == 0);
        my $i = int (($cur-$first)/86400);
        $p[$i]++;
      }

      END {
        foreach my $i (0..$#p) {
          if ($i < 4)  {
            printf ("%5i", $p[$i]);
          } else  {
            if ($p[$i]) {
              printf ("%4i", $p[$i]);
            } else  {
              print " x";
            }
          }
          if ($i != $#p && $i % 7 == 6)  {
            print ".";
          }
        }
        print "\n";
      }
    '
  done
}


# gives sth. like:
#
# 13.0-abi32+64_20170216-202818              1:53 min  mail-filter/assp
# desktop_20170218-203252                   72:08 min  sdlmame
# desktop-libressl-abi32+64_20170215-18565   0:03 min  dev-ruby/stringex
#
function CurrentTask()  {
  for i in $images
  do
    PrintImageName
    tsk=$i/tmp/task
    if [[ ! -f $tsk || ! -f $i/tmp/LOCK ]]; then
      echo
      continue
    fi

    let "delta = $(date +%s) - $(date +%s -r $tsk)"
    let "seconds = $delta % 60"
    let "minutes = $delta / 60"
    printf " %3i:%02i min  " $minutes $seconds
    cat $tsk
  done
}


#######################################################################
#
images=$(list_images)

echo "$(echo $images | wc -w) images ($(ls ~/img? | wc -w) at all) :"

while getopts hlopt\? opt
do
  case $opt in
    l)  LastEmergeOperation
        ;;
    o)  Overall
        ;;
    p)  PackagesPerDay
        ;;
    t)  CurrentTask
        ;;
    *)  echo "call: $(basename $0) [-l] [-o] [-p] [-t]"
        echo
        exit 0
        ;;
  esac
  echo
done
