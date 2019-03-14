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

if [[ -z "${versionToInstall}" ]] ; then
    echo "No version to install (tag) given, installing latest release"
    githubTag=$(curl -L -s https://api.github.com/repos/spectrecoin/spectre/releases/latest | grep tag_name | cut -d: -f2 | cut -d '"' -f2)
else
    githubTag=${versionToInstall}
fi
echo ""

echo "Determining system"
if [[ -e /etc/os-release ]] ; then
    . /etc/os-release
else
    echo "File /etc/os-release not found, not updating anything"
    exit 1
fi
echo "    Determined $NAME"
echo ""

usedDistro=''
case ${ID} in
    "debian")
        usedDistro="Debian"
        ;;
    "ubuntu")
        usedDistro="Ubuntu"
        ;;
    "fedora")
        usedDistro="Fedora"
        ;;
    "raspbian")
        usedDistro="RaspberryPi"
        ;;
esac

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
# **Spectrecoin-Build139-0c97a29-Debian.tgz:** `1128be441ff910ef31361dfb04273618b23809ee25a29ec9f67effde060c53bb`
officialChecksum=$(grep "${usedDistro}.tgz:" ${tmpWorkdir}/${tmpChecksumfile} | cut -d '`' -f2)
filenameToDownload=$(grep "${usedDistro}.tgz:" ${tmpWorkdir}/${tmpChecksumfile} | cut -d '*' -f3 | sed "s/://g")

echo "Downloading binary archive ${downloadBaseURL}/${filenameToDownload}"
httpCode=$(curl -L -o ${tmpWorkdir}/${tmpBinaryArchive} -w "%{http_code}" ${downloadBaseURL}/${filenameToDownload})
if [[ ${httpCode} -ge 400 ]] ; then
    echo "Archive ${downloadBaseURL}/${filenameToDownload} not found!"
    exit 1
fi
echo "    Done"
echo ""

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

if [[ -e ${installPath}/spectrecoind ]] ; then
    # Option '-version' is working since v3.x
    #currentVersion=$(${installPath}/spectrecoind -version)
    # At the moment use a workaround
    currentVersion=$(strings ${installPath}/spectrecoind | grep "v[123]\..\..\." | head -n 1)
    if [[ -z "${currentVersion}" ]] ; then
        currentVersion=$(date +%Y%m%d-%H%M)
        echo "Unable to determine version of current binaries, using timestamp '${currentVersion}'"
    else
        echo "Creating backup of current version ${currentVersion}"
    fi
    if [[ -f ${installPath}/spectrecoind-${currentVersion} ]] ; then
        echo "    Backup of current version already existing"
    else
        mv ${installPath}/spectrecoin  ${installPath}/spectrecoin-${currentVersion}
        mv ${installPath}/spectrecoind ${installPath}/spectrecoind-${currentVersion}
        echo "    Done"
    fi
else
    echo "Binary ${installPath}/spectrecoind not found, skip backup creation"
fi
echo ""

echo "Installing new binaries"
cd ${tmpWorkdir}
tar xzf ${tmpBinaryArchive} .
mv usr/local/bin/spectre* /usr/local/bin/
chmod +x /usr/local/bin/spectre*
echo "    Done"
echo ""

echo "Cleanup"
rm -rf ${tmpWorkdir}
echo "    Done"
echo ""
