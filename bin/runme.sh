#!/bin/sh
#
# set -x

# wrapper which allows to edit job.sh whilst a copy of it is in use
#
mailto="tinderbox@zwiebeltoralf.de"

# run a copy to allow editing of the origin
# change job.sh to use the current job.sh asap
#
orig=/tmp/tb/bin/job.sh
copy=/tmp/job.sh

rc=-1

while :;
do
  # 2 checks to avoid a race during copy operation
  #
  cp $orig $copy
  rc=$?
  if [[ $rc -ne 0 ]]; then
    break
  fi

  if [[ -s $copy ]]; then
    /bin/bash -n $copy
    rc=$?

    if [[ $rc -eq 0 ]]; then
      /bin/bash $copy
      rc=$?

      # rc=125: job.sh signaled to restart a newer version of job.sh
      #
      if [[ $rc -ne 125 ]]; then
        break
      fi
    fi
  fi
done

if [[ $rc -gt 127 ]]; then
  name=$(grep "^PORTAGE_ELOG_MAILFROM=" /etc/portage/make.conf | cut -f2 -d '"' | cut -f1 -d ' ')
  date | mail -s "$(basename $0): $name rc=$rc" $mailto
fi

exit $rc
