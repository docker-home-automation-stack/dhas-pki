#!/bin/sh
# Original script:
# https://raw.githubusercontent.com/ellerbrock/docker-collection/master/dockerfiles/alpine-harden/harden.sh

set -x
set -e

# Be informative after successful login.
echo -e "\n\nApp container image built on $(date)." > /etc/motd

# Improve strength of diffie-hellman-group-exchange-sha256 (Custom DH with SHA2).
# See https://stribika.github.io/2015/01/04/secure-secure-shell.html
#
# Columns in the moduli file are:
# Time Type Tests Tries Size Generator Modulus
#
# This file is provided by the openssh package on Fedora.
moduli=/etc/ssh/moduli
if [[ -f ${moduli} ]]; then
  echo "DH strengthening in /etc/ssh/moduli ..."
  cp ${moduli} ${moduli}.orig
  awk '$5 >= 2000' ${moduli}.orig > ${moduli}
  rm -f ${moduli}.orig
fi

# Remove existing crontabs, if any.
echo "Remove crontabs ..."
rm -frv /var/spool/cron
rm -frv /etc/crontabs
rm -frv /etc/periodic

# Remove all but a handful of admin commands.
echo "Remove admin commands ..."
find /sbin /usr/sbin \( ! -type d \
  -a ! -name addgroup \
  -a ! -name adduser \
  -a ! -name jq \
  -a ! -name su-exec \
  \) -exec rm -fv {} \;

# Remove world-writable permissions.
# This breaks apps that need to write to /tmp,
# such as ssh-agent.
echo "Remove world-writable permissions ..."
find / -xdev -type d -perm +0002 -exec chmod -v o-w {} +
find / -xdev -type f -perm +0002 -exec chmod -v o-w {} +

# Remove unnecessary user accounts.
echo "Remove unnecessary user accounts ..."
sed -i -r "/^(${SERVICE_USER}|root|sshd)/!d" /etc/group
sed -i -r "/^(${SERVICE_USER}|root|sshd)/!d" /etc/passwd

# Remove interactive login shell for everybody but user.
echo "Remove interactive login shell ..."
sed -i -r '/^'${SERVICE_USER}':/! s#^(.*):[^:]*$#\1:/sbin/nologin#' /etc/passwd

sysdirs="
  /bin
  /etc
  /lib
  /sbin
  /usr
"

# Remove apk configs.
echo "Remove apk configs ..."
find $sysdirs -xdev -regex '.*apk.*' -exec rm -frv {} +

# Remove crufty...
#   /etc/shadow-
#   /etc/passwd-
#   /etc/group-
echo "Remove crufty files ..."
find $sysdirs -xdev -type f -regex '.*-$' -exec rm -fv {} +

# Ensure system dirs are owned by root and not writable by anybody else.
echo "Enforce system dir permissions ..."
find $sysdirs -xdev -type d \
  -exec chown -v root:root {} \; \
  -exec chmod -v 0755 {} \;

# Remove all suid files.
echo "Remove all suid files ..."
find $sysdirs -xdev -type f -a -perm +4000 -exec rm -frv {} \;

# Remove other programs that could be dangerous.
echo "Remove other potentially dangerous programs ..."
find $sysdirs -xdev \( \
  -name hexdump -o \
  -name od -o \
  -name strings -o \
  -name su \
  \) -exec rm -frv {} \;

# Remove init scripts since we do not use them.
echo "Remove init scripts ..."
rm -frv /etc/init.d
rm -frv /lib/rc
rm -frv /etc/conf.d
rm -frv /etc/inittab
rm -frv /etc/runlevels
rm -frv /etc/rc.conf

# Remove kernel tunables since we do not need them.
echo "Remove kernel tunables ..."
rm -frv /etc/sysctl*
rm -frv /etc/modprobe.d
rm -frv /etc/modules
rm -frv /etc/mdev.conf
rm -frv /etc/acpi

# Remove root homedir since we do not need it.
echo "Remove root homedir content ..."
rm -frv /root/*

# Remove fstab since we do not need it.
echo "Remove fstab ..."
rm -fv /etc/fstab

# Remove broken symlinks (because we removed the targets above).
echo "Remove broken symlinks ..."
find $sysdirs -xdev -type l -exec test ! -e {} \; -delete

# delete oneself
echo "Self-destruction ..."
rm -fv -- "$0"
