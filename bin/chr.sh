#!/bin/sh
#
#set -x

# chroot wrapper, bind mount file systems of the host to their image counter parts
#
# typical call:
#
# $> sudo ~/tb/bin/chr.sh amd64-plasma-unstable_20150811-144142 [ "eix-update -q" ]

# due to sudo we need to define the path of $HOME of the tinderbox user
#
tbhome=/home/tinderbox

function mountall() {
  mount -o bind       $tbhome/tb            $mnt/tmp/tb             &&\
  mount -o bind,ro    /usr/portage          $mnt/usr/portage        &&\
  mount -o bind       /home/tinderbox/images/distfiles    $mnt/var/tmp/distfiles  &&\
  mount -t tmpfs      tmpfs -o size=9G      $mnt/var/tmp/portage    &&\

  mount -t proc       none                  $mnt/proc               &&\
  mount --rbind       /sys                  $mnt/sys                &&\
  mount --make-rslave $mnt/sys                                      &&\
  mount --rbind       /dev                  $mnt/dev                &&\
  mount --make-rslave $mnt/dev

  return $?
}


function umountall()  {
  umount -l $mnt/dev{/shm,/pts,}
  umount -l $mnt/{sys,proc}
  umount    $mnt/var/tmp/{portage,distfiles}
  umount    $mnt/usr/portage
  umount    $mnt/tmp/tb
}


#############################################################################
#                                                                           #
# main                                                                      #
#                                                                           #
#############################################################################
if [[ ! "$(whoami)" = "root" ]]; then
  echo " you must be root !"
  exit 1
fi

# usually we get the symlink of the chroot image int $HOME of tinderbox
#
mnt=$1

# treat remaining as a command line to be run within chroot
#
shift

if [[ ! -d "$mnt" ]]; then
  echo
  echo " error: NOT a valid dir: $mnt"
  echo

  exit 1
fi

# 1st barrier to prevent starting a chroot image twice: a lock file
#
lock=$mnt/tmp/LOCK
if [[ -f $lock ]]; then
  echo "found lock file $lock"
  exit 1
fi
touch $lock || exit 2

# 2nd barrier to prevent starting a chroot image twice: grep mount table
# this is a weak condition b/c a mount can be made using a symlink name
#
grep -m 1 "$(basename $mnt)" /proc/mounts && exit 3

# ok, mount now the directories from the host
#
mountall || exit 4

# sometimes resolv.conf is symlinked to var/run: bug https://bugs.gentoo.org/show_bug.cgi?id=555694
# so remove it before
#
rm -f                   $mnt/etc/resolv.conf
cp -L /etc/resolv.conf  $mnt/etc/resolv.conf
cp -L /etc/hosts        $mnt/etc/hosts

if [[ $# -gt 0 ]]; then
  # enforce a login of user root to ensure that its environment is sourced
  #
  /usr/bin/chroot $mnt /bin/bash -l -c "su - root -c '$@'"
else
  /usr/bin/chroot $mnt /bin/bash -l
fi
rc=$?

umountall
rm $lock

exit $rc
