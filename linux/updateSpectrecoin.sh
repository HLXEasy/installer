#!/usr/bin/env bash
# ============================================================================
#
# FILE:         updateSpectrecoin.sh
#
# DESCRIPTION:  Simple installer script to update local Spectrecoin binaries
#
# AUTHOR:       HLXEasy
# PROJECT:      https://spectreproject.io/
#               https://github.com/spectrecoin/spectre
#
# ============================================================================

versionToInstall=$1
installPath=/usr/local/bin
tmpWorkdir=/tmp/SpectrecoinUpdate
tmpChecksumfile=checksumfile.txt
tmpBinaryArchive=Spectrecoin.tgz
backportsRepo="deb http://ftp.debian.org/debian stretch-backports main"
torRepoBionic="deb https://deb.torproject.org/torproject.org bionic main"
torRepoBuster="deb https://deb.torproject.org/torproject.org buster main"
boostVersion='1.67.0'

# ----------------------------------------------------------------------------
# Define version to install
if [[ -z "${versionToInstall}" ]] ; then
    echo "No version to install (tag) given, installing latest release"
    githubTag=$(curl -L -s https://api.github.com/repos/spectrecoin/spectre/releases/latest | grep tag_name | cut -d: -f2 | cut -d '"' -f2)
else
    githubTag=${versionToInstall}
fi
echo ""

# ----------------------------------------------------------------------------
# Determining current operating system (distribution)
echo "Determining system"
if [[ -e /etc/os-release ]] ; then
    . /etc/os-release
else
    echo "File /etc/os-release not found, not updating anything"
    exit 1
fi
echo "    Determined $NAME"
echo ""

# ----------------------------------------------------------------------------
# Define some variables
usedDistro=''
useBackports=false
backportsFile=''
torRepoFile="/etc/apt/sources.list.d/tor.list"
torRepo=''
releaseName=''
case ${ID} in
    "debian")
        usedDistro="Debian"
        case ${VERSION_ID} in
            "9")
                useBackports=true
                backportsFile="/etc/apt/sources.list.d/stretch-backports.list"
                releaseName='-Stretch'
                ;;
            "10")
                torRepoFile="/etc/apt/sources.list.d/buster-tor.list"
                torRepo=${torRepoBuster}
                releaseName='-Buster'
                ;;
            *)
                echo "Unsupported operating system ID=${ID}, VERSION_ID=${VERSION_ID}"
                exit
                ;;
        esac
        ;;
    "ubuntu")
        usedDistro="Ubuntu"
        case ${VERSION_CODENAME} in
            "bionic")
                torRepo=${torRepoBionic}
                ;;
        esac
        ;;
    "fedora")
        usedDistro="Fedora"
        ;;
    "raspbian")
        usedDistro="RaspberryPi"
        case ${VERSION_ID} in
            "9")
                useBackports=true
                backportsFile="/etc/apt/sources.list.d/stretch-backports.list"
                releaseName='-Stretch'
                ;;
            "10")
                torRepoFile="/etc/apt/sources.list.d/buster-tor.list"
                torRepo=${torRepoBuster}
                releaseName='-Buster'
                ;;
            *)
                echo "Unsupported operating system ID=${ID}, VERSION_ID=${VERSION_ID}"
                exit
                ;;
        esac
        ;;
    *)
        echo "Unsupported operating system ${ID}, VERSION_ID=${VERSION_ID}"
        exit
        ;;
esac

# ----------------------------------------------------------------------------
# Create work dir and download release notes and binary archive
mkdir -p ${tmpWorkdir}

#https://github.com/spectrecoin/spectre/releases/latest
#https://github.com/spectrecoin/spectre/releases/download/2.2.1/Spectrecoin-2.2.1-8706c85-Ubuntu.tgz
#https://github.com/spectrecoin/spectre/releases/download/Build127/Spectrecoin-Build127-8e152a8-Debian.tgz
downloadBaseURL=https://github.com/spectrecoin/spectre/releases/download/${githubTag}
releasenotesToDownload=${downloadBaseURL}/RELEASENOTES.txt
echo "Downloading release notes with checksums ${releasenotesToDownload}"
httpCode=$(curl -L -o ${tmpWorkdir}/${tmpChecksumfile} -w "%{http_code}" ${releasenotesToDownload})
if [[ ${httpCode} -ge 400 ]] ; then
    echo "${releasenotesToDownload} not found!"
    exit 1
fi
echo "    Done"
echo ""
# Desired line of text looks like this:
# **Spectrecoin-Build139-0c97a29-Debian-Buster.tgz:** `1128be441ff910ef31361dfb04273618b23809ee25a29ec9f67effde060c53bb`
officialChecksum=$(grep "${usedDistro}${releaseName}.tgz:" ${tmpWorkdir}/${tmpChecksumfile} | cut -d '`' -f2)
filenameToDownload=$(grep "${usedDistro}${releaseName}.tgz:" ${tmpWorkdir}/${tmpChecksumfile} | cut -d '*' -f3 | sed "s/://g")

# If nothing found, try again without ${releaseName}
if [[ -z "${officialChecksum}" ]] || [[ -z "${filenameToDownload}" ]] ; then
    # **Spectrecoin-Build139-0c97a29-Debian.tgz:** `1128be441ff910ef31361dfb04273618b23809ee25a29ec9f67effde060c53bb`
    officialChecksum=$(grep "${usedDistro}.tgz:" ${tmpWorkdir}/${tmpChecksumfile} | cut -d '`' -f2)
    filenameToDownload=$(grep "${usedDistro}.tgz:" ${tmpWorkdir}/${tmpChecksumfile} | cut -d '*' -f3 | sed "s/://g")
fi

echo "Downloading binary archive ${downloadBaseURL}/${filenameToDownload}"
httpCode=$(curl -L -o ${tmpWorkdir}/${tmpBinaryArchive} -w "%{http_code}" ${downloadBaseURL}/${filenameToDownload})
if [[ ${httpCode} -ge 400 ]] ; then
    echo "Archive ${downloadBaseURL}/${filenameToDownload} not found!"
    exit 1
fi
echo "    Done"
echo ""

# ----------------------------------------------------------------------------
# Get checksum from release notes and verify downloaded archive
echo "Verifying checksum"
determinedSha256Checksum=$(sha256sum ${tmpWorkdir}/${tmpBinaryArchive} | awk '{ print $1 }')
if [[ "${officialChecksum}" != "${determinedSha256Checksum}" ]] ; then
    echo "ERROR: sha256sum of downloaded file not matching value from ${releasenotesToDownload}: (${officialChecksum} != ${determinedSha256Checksum})"
    exit 1
else
    echo "    sha256sum OK"
fi
echo "    Downloaded archive is ok, checksums match values from ${releasenotesToDownload}"
echo ""

# ----------------------------------------------------------------------------
# If necessary, check for configured backports and Tor repo
if [[ -n "${backportsFile}" ]] ; then
    if [[ -e ${backportsFile} ]] ; then
        echo "Backports repo already configured"
    else
        echo "Adding backports repo"
        echo "${backportsRepo}" | sudo tee --append ${backportsFile} > /dev/null
        echo "    Done"
    fi
    echo ""
fi
if [[ -n "${torRepo}" ]] ; then
    if [[ -e ${torRepoFile} ]] ; then
        echo "Tor repo already configured"
    else
        echo "Adding Tor repo"
        echo "${torRepo}" | sudo tee --append ${torRepoFile} > /dev/null
        echo "    Done"
    fi
    echo ""
fi

# ----------------------------------------------------------------------------
# Update the whole system
echo "Updating system"
case ${ID} in
    "debian"|"raspbian")
        sudo apt-get update -y \
            && sudo apt-get install -y \
                apt-transport-https \
                deb.torproject.org-keyring \
            && sudo apt-get upgrade -y \
            && sudo apt-get install -y \
                --no-install-recommends \
                --allow-unauthenticated \
                libboost-chrono${boostVersion} \
                libboost-filesystem${boostVersion} \
                libboost-program-options${boostVersion} \
                libboost-thread${boostVersion} \
                tor \
            && apt-get clean
        ;;
    "ubuntu")
        sudo apt-get update -y && sudo apt-get upgrade -y && sudo apt-get install -y \
            --no-install-recommends \
            tor \
            && apt-get clean
        ;;
    "fedora")
        sudo dnf update -y && sudo dnf install -y \
            tor \
            && dnf clean all
        ;;
esac
echo "    Done"
echo ""


# ----------------------------------------------------------------------------
# Handle old binary location /usr/bin/
if [[ -e /usr/bin/spectrecoind && ! -L /usr/bin/spectrecoind ]] ; then
    # Binary found on old location and is _not_ a symlink,
    # so move to new location and create symlink
    echo "Found binaries on old location, cleaning them up"
    mv /usr/bin/spectrecoind ${installPath}/spectrecoind
    ln -s ${installPath}/spectrecoind /usr/bin/spectrecoind
    if [[ -e /usr/bin/spectrecoin && ! -L /usr/bin/spectrecoin ]] ; then
        mv /usr/bin/spectrecoin ${installPath}/spectrecoin
        ln -s ${installPath}/spectrecoin /usr/bin/spectrecoin
    fi
    echo "    Done"
    echo ""
fi

# ----------------------------------------------------------------------------
# Backup wallet.dat
if [[ -e ~/.spectrecoin/wallet.dat ]] ; then
    backupFile=$(date +%Y-%m-%d_%H-%M)-wallet.dat
    echo "Creating backup of wallet.dat (${backupFile})"
    cp ~/.spectrecoin/wallet.dat ~/${backupFile}
    echo "    Done"
fi
if [[ -e ~/.spectrecoin/testnet/wallet.dat ]] ; then
    backupFile=$(date +%Y-%m-%d_%H-%M)-testnet-wallet.dat
    echo "Creating backup of testnet wallet.dat (${backupFile})"
    cp ~/.spectrecoin/testnet/wallet.dat ~/${backupFile}
    echo "    Done"
fi
echo ""

# ----------------------------------------------------------------------------
# Backup current binaries
if [[ -e ${installPath}/spectrecoind ]] ; then
    echo "Determining current binary version"
    # Version is something like "v2.2.2.0 (86e9b92 - 2019-01-26 17:20:20 +0100)"
    # but only the version and the commit hash separated by "_" is used later on.
    # Option '-version' is working since v3.x
    queryResult=$(${installPath}/spectrecoind -version)
    currentVersion=$(echo ${queryResult/\(/} | cut -d ' ' -f 1)
    gitHash=$(echo ${queryResult/\(/} | cut -d ' ' -f 2)
    if [[ -n "${gitHash}" ]] ; then
        fullVersion=${currentVersion}-${gitHash}
    else
        fullVersion=${currentVersion}
    fi

    # At the moment use a workaround
    #fullVersion=$(strings ${installPath}/spectrecoind | grep "v[123]\..\..\." | head -n 1 | sed -e "s/(//g" -e "s/)//g" | cut -d " " -f1-2 | sed "s/ /_/g")
    if [[ -z "${fullVersion}" ]] ; then
        fullVersion=$(date +%Y%m%d-%H%M)
        echo "    Unable to determine version of current binaries, using timestamp '${fullVersion}'"
    else
        echo "    Creating backup of current version ${fullVersion}"
    fi
    if [[ -f ${installPath}/spectrecoind-${fullVersion} ]] ; then
        echo "    Backup of current version already existing"
    else
        mv ${installPath}/spectrecoind ${installPath}/spectrecoind-${fullVersion}
        if [[ -e ${installPath}/spectrecoin ]] ; then
            mv ${installPath}/spectrecoin  ${installPath}/spectrecoin-${fullVersion}
        fi
        echo "    Done"
    fi
else
    echo "Binary ${installPath}/spectrecoind not found, skip backup creation"
fi
echo ""

# ----------------------------------------------------------------------------
# Install new binaries
echo "Installing new binaries"
cd ${tmpWorkdir}
tar xzf ${tmpBinaryArchive} .
mv usr/local/bin/spectre* /usr/local/bin/
chmod +x /usr/local/bin/spectre*
echo "    Done"
echo ""

# ----------------------------------------------------------------------------
# Cleanup temporary data
echo "Cleanup"
rm -rf ${tmpWorkdir}
echo "    Done"
echo ""
