#!/bin/bash -e

HELP_STR="Usage: ./ubuntu-setup [-y | --yes] [-n | --noclobber] [-c | --clobber] [-f | --firmware] [-nf | --nofirmware] [-osl | --overwrite-sources-list ] [-h | --help]
\tyes:\t\t\tassume no user input
\tnoclobber:\t\tdont install 3rd party repositories
\tclobber:\t\tInstall 3rd party repositories
\tfirmware:\t\tInstall firmware repository
\tnofirmware:\t\tPrevents installation of firmware deps firmware repository
\toverwrite-sources-list:\tOverwrites the sources.list with gatech mirrors for faster ubuntu-setup. Only works on ubuntu > precise.
\thelp:\t\t\tprint this message!
This script will need root privileges"

DISTRO_STR="The linux distro you are using is not supported by ubuntu-setup. Please file an issue if you want to request your debian based distro to be added."

# defaults!
OVERWRITE_SOURCES=false
YES=false
SYSTEM="unknown"
NO_SUBMODULES=false

BASE=$(readlink -f $(dirname $0)/..)

if cat /etc/os-release | grep -iq '^NAME=.*Debian'; then # don't add repositories on debian, unsupported
    echo "[WARN] You are using a flavor of debian. This configuration is not officially supported..." >&2
    SYSTEM="debian"
    ADD_REPOS=false
elif cat /etc/os-release | grep -iq '^NAME=.*Ubuntu'; then # We are using a version of ubuntu...
    if cat /etc/os-release | grep -iq '^VERSION=.*20.04'; then # Using Ubuntu 20.04
        echo "Ubuntu 20.04 Detected..."
        SYSTEM="ubuntu-20.04"
        ADD_REPOS=false
    else
        echo "Sorry, we only support 20.04 due to ROS2." >&2
        echo "$DISTRO_STR" >&2
        exit 1
    fi
else
    echo "$DISTRO_STR" >&2
    exit 1
fi

# parse command line args
for i in "$@"
do
    case $i in
        -y|--yes)
            YES=true
            ;;
        -n|--noclobber)
            # This option omits the addition of the 3rd party repos
            ADD_REPOS=false
            ;;
        -c|--clobber)
            # This option forces addition of the custom repos
            ADD_REPOS=true
            ;;
        -osl|--overwrite-sources-list)
            # This option overwrites the sources list for faster downloads
            OVERWRITE_SOURCES=true
            ;;
        -h|--help)
            echo -e "$HELP_STR"
            exit 1
            ;;
        --no-submodules)
            # only for CI
            NO_SUBMODULES=true
            ;;
        *)
            echo "Unrecognized Option: $i"
            echo -e "\n$HELP_STR"
            exit 1
            # unknown options
            ;;
    esac
done

# Become root
if [ $UID -ne 0 ]; then
	echo "-- Becoming root"
	exec sudo $0 $@
fi

if $OVERWRITE_SOURCES; then
    read -p "Do you really want to overwrite your sources.list? THIS SHOULD ONLY BE DONE ON STOCK UBUNTU [yN]: " yn
    case $yn in
        [Yy]* ) ;;
        [Nn]* ) exit;;
        * ) exit ;;
    esac

    # Copy sources.list to sources.list.old if sources.list.old is empty
    if [ -f "/etc/apt/sources.list" ]; then
        cp -n /etc/apt/sources.list /etc/apt/sources.list.old
    else
        echo "A prior /etc/apt/sources.list was not found! This probably means you are on a non-debian based system! To force override, run: touch /etc/apt/sources.list" 1>&2
        exit 1
    fi

    # Cross our fingers...
    sed -i 's%^\s*\([^#]\S\+\)\s\+\S\+%\1 mirror://mirrors.ubuntu.com/mirrors.txt%' /etc/apt/sources.list
EOF

fi

if $ADD_REPOS; then
    # add repo for backport of cmake3 from debian testing
    # TODO remove this once ubuntu ships cmake3
    sudo add-apt-repository -y ppa:george-edison55/cmake-3.x

    # for newer compilers
    add-apt-repository -y ppa:ubuntu-toolchain-r/test
fi

# if yes option is checked, add  a -y
ARGS=""
if $YES; then
    ARGS="-y"
fi

# Add the llvm key
# Fingerprint: 6084 F3CF 814B 57C1 CF12 EFD5 15CF 4D18 AF4F 7421
apt-get install -y $ARGS wget curl # Somehow we don't have wget

# Somehow 16.04 doesn't support https
wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -

# Install clang-format-10 using llvm repo
if [ "$SYSTEM" = "ubuntu-20.04" ]; then
    sudo add-apt-repository -s "deb http://apt.llvm.org/focal/ llvm-toolchain-focal-10 main"
fi

# Add ROS key and repo
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8
sudo apt-get update && sudo apt-get install -y curl gnupg2 lsb-release
curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add -
sudo sh -c 'echo "deb http://packages.ros.org/ros2/ubuntu `lsb_release -cs` main" > /etc/apt/sources.list.d/ros2-latest.list'
sudo apt-get update

# Install eloquent for 18.04, foxy for 20.04
if [ "$SYSTEM" = "ubuntu-20.04" ]; then
    sudo apt-get install -y ros-foxy-ros-base
fi

MACH=$(uname -m)
unset DPKG_FLAGS

echo "-- Installing udev rules"
cp -f "$BASE"/util/robocup.rules /etc/udev/rules.d/
udevadm control --reload || true # reload rules

echo "-- Installing required packages"

PACKAGES="$(sed 's/#.*//;/^$/d' $BASE/util/ubuntu-packages.txt)"

# install all of the packages listed in required_packages.txt
apt-get install -y $ARGS $PACKAGES

# install python3 requirements
pip3 install --upgrade pip
pip3 install -r $BASE/util/requirements3.txt

echo "-- Installing grSim default configuration"
GRSIM_XML_INSTALL_LOCATION="$HOME/.grsim.xml"
SOURCE_GRSIM_XML_LOCATION="$BASE"/grsim.xml

if [ "$(readlink -f "$GRSIM_XML_INSTALL_LOCATION")" == "$SOURCE_GRSIM_XML_LOCATION" ]; then
    echo "-- grSim default configuration is already installed! Doing nothing."
else
    if test -f "$GRSIM_XML_INSTALL_LOCATION"; then
        echo "$HOME/.grsim.xml exists! Renaming it to grsim.xml.old..."
        mv "$HOME/.grsim.xml" "$HOME/.grsim.xml.old"
    fi
    ln -vsf "$SOURCE_GRSIM_XML_LOCATION" "$GRSIM_XML_INSTALL_LOCATION"
fi

# This script is run as sudo, but we don't want submodules to be owned by the
# root user, so we use `su` to update submodules as the normal user
SETUP_USER="$SUDO_USER"
if [ -z "$SETUP_USER" ]; then
    SETUP_USER="$(whoami)"
fi

if [ "$NO_SUBMODULES" != "true" ]; then
    # This script is run as sudo, but we don't want submodules to be owned by the
    # root user, so we use `su` to update submodules as the normal user
    echo "-- Updating submodules"
    SETUP_USER="$SUDO_USER"
    if [ -z "$SETUP_USER" ]; then
        SETUP_USER="$(whoami)"
    fi
    chown -R $SETUP_USER:$SETUP_USER $BASE/external
    su $SETUP_USER -c 'git submodule sync'
    su $SETUP_USER -c 'git submodule update --init --recursive'
fi