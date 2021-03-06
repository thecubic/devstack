#!/bin/bash

set -x

# Configurable nuggets
GUEST_PASSWORD=${GUEST_PASSWORD:-secrete}
STAGING_DIR=${STAGING_DIR:-stage}
DO_TGZ=${DO_TGZ:-1}

# Install basics
chroot $STAGING_DIR apt-get update
chroot $STAGING_DIR apt-get install -y cracklib-runtime curl wget ssh openssh-server tcpdump ethtool
chroot $STAGING_DIR apt-get install -y curl wget ssh openssh-server python-pip git vim-nox sudo
chroot $STAGING_DIR pip install xenapi

# Install guest utilities
XEGUEST=xe-guest-utilities_5.6.100-651_amd64.deb
wget http://images.ansolabs.com/xen/$XEGUEST -O $XEGUEST
cp $XEGUEST $STAGING_DIR/root
chroot $STAGING_DIR dpkg -i /root/$XEGUEST
chroot $STAGING_DIR update-rc.d -f xe-linux-distribution remove
chroot $STAGING_DIR update-rc.d xe-linux-distribution defaults

# Make a small cracklib dictionary, so that passwd still works, but we don't
# have the big dictionary.
mkdir -p $STAGING_DIR/usr/share/cracklib
echo a | chroot $STAGING_DIR cracklib-packer

# Make /etc/shadow, and set the root password
chroot $STAGING_DIR "pwconv"
echo "root:$GUEST_PASSWORD" | chroot $STAGING_DIR chpasswd

# Put the VPX into UTC.
rm -f $STAGING_DIR/etc/localtime

# Add stack user
chroot $STAGING_DIR groupadd libvirtd
chroot $STAGING_DIR useradd stack -s /bin/bash -d /opt/stack -G libvirtd
echo stack:$GUEST_PASSWORD | chroot $STAGING_DIR chpasswd
echo "stack ALL=(ALL) NOPASSWD: ALL" >> $STAGING_DIR/etc/sudoers

# Give ownership of /opt/stack to stack user
chroot $STAGING_DIR chown -R stack /opt/stack

# Make our ip address hostnames look nice at the command prompt
echo "export PS1='${debian_chroot:+($debian_chroot)}\\u@\\H:\\w\\$ '" >> $STAGING_DIR/opt/stack/.bashrc
echo "export PS1='${debian_chroot:+($debian_chroot)}\\u@\\H:\\w\\$ '" >> $STAGING_DIR/root/.bashrc
echo "export PS1='${debian_chroot:+($debian_chroot)}\\u@\\H:\\w\\$ '" >> $STAGING_DIR/etc/profile

function setup_vimrc {
    if [ ! -e $1 ]; then
        # Simple but usable vimrc
        cat > $1 <<EOF
syntax on
se ts=4
se expandtab
se shiftwidth=4
EOF
    fi
}

# Setup simple .vimrcs
setup_vimrc $STAGING_DIR/root/.vimrc
setup_vimrc $STAGING_DIR/opt/stack/.vimrc

if [ "$DO_TGZ" = "1" ]; then
    # Compress
    rm -f stage.tgz
    tar cfz stage.tgz stage
fi
