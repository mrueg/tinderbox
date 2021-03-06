# #!/bin/sh
#
# set -x

# this is a (s)imple (c)hroot (w)rapper to go into a (running) tinderbox image
# it will not mound any file systems like /dev, /proc and so on

if [[ $# -ne 1 ]]; then
  echo
  echo " an image is expected !"
  echo
  exit 1
fi

mnt=$1

# guess a location if just the name is given
#
if [[ ! -d $mnt ]]; then
  tmp=$(ls -d /home/tinderbox/{run,img?}/$mnt 2>/dev/null | head -n 1)
  if [[ ! -d $tmp ]]; then
    echo
    echo " cannot guess the full path to the image $mnt"
    echo
    exit 1
  fi
  mnt=$tmp
  echo
  echo " no full path were given, choosing: $mnt"
  echo
fi

sudo /usr/bin/chroot $mnt

exit $?
