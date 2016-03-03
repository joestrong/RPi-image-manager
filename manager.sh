#!/bin/bash

echo "-----------------------------------------"
echo " Raspberry Pi Image Manager (RIM) v0.3.4 "
echo "-----------------------------------------"

# Get the source directory
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi

# Set the library root path
LIBRARY_PATH_ROOT="$DIR/utils"

# Include the generic libraries
. "$LIBRARY_PATH_ROOT/generic.sh"
. "$LIBRARY_PATH_ROOT/colours.sh"

# Set default options
IMAGE_LIST=false

# Get any params defined
for i in "$@"
do
case $i in
        -l|--list-images)	IMAGE_LIST=true ;;
        -*)					echo "UNKNOWN PARAMETER ${i#*=}"; exit ;;
esac
done

declare -A Images

Images['Raspbian-Whezzy']="https://downloads.raspberrypi.org/raspbian/images/raspbian-2015-05-07/2015-05-05-raspbian-wheezy.zip"
Images['Raspbian-Jessie']="https://downloads.raspberrypi.org/raspbian/images/raspbian-2016-02-09/2016-02-09-raspbian-jessie.zip"
Images['Raspbian-Jessie-Lite']="https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2016-02-09/2016-02-09-raspbian-jessie-lite.zip"
Images['Minbian']="http://downloads.sourceforge.net/project/minibian/2015-11-12-jessie-minibian.tar.gz"
Images['Snappy']="http://cdimage.ubuntu.com/ubuntu-snappy/15.04/stable/latest/ubuntu-15.04-snappy-armhf-raspi2.img.xz"
Images['OpenELEC']="http://releases.openelec.tv/OpenELEC-RPi.arm-6.0.1.img.gz"
Images['OpenELECPi2']="http://releases.openelec.tv/OpenELEC-RPi2.arm-6.0.1.img.gz"
Images['OSMC']="http://download.osmc.tv/installers/diskimages/OSMC_TGT_rbp1_20160130.img.gz"
Images['OSMCPi2']="http://download.osmc.tv/installers/diskimages/OSMC_TGT_rbp2_20160130.img.gz"
Images['Pidora']="http://pidora.ca/pidora/releases/20/images/Pidora-2014-R3.zip"
Images['RISCOS']="https://www.riscosopen.org/zipfiles/platform/raspberry-pi/riscos-2015-02-17.14.zip"
Images['RetroPi']="https://github.com/RetroPie/RetroPie-Setup/releases/download/3.4/retropie-v3.4-rpi1.img.gz"
Images['RetroPi2']="https://github.com/RetroPie/RetroPie-Setup/releases/download/3.4/retropie-v3.4-rpi2.img.gz"
Images['MATE']="https://ubuntu-mate.r.worldssl.net/raspberry-pi/ubuntu-mate-15.10.1-desktop-armhf-raspberry-pi-2.img.xz"
Images['Windows-10-IOT-Core']="http://go.microsoft.com/fwlink/?LinkId=691711"


declare -A ImagesSHA1

ImagesSHA1['Raspbian-Whezzy']="cb799af077930ff7cbcfaa251b4c6e25b11483de"
ImagesSHA1['Raspbian-Jessie']="da329713833e0785ffd94796304b7348803381db"
ImagesSHA1['Raspbian-Jessie-Lite']="bb7bcada44957109f1c3eb98548951d0ba53b9c4"
ImagesSHA1['Minbian']="0ec01c74c5534101684c64346b393dc169ebd1af"
ImagesSHA1['Snappy']="2d32d93e0086593fe34b8c07d4af7227c79addd3"
ImagesSHA1['OpenELEC']="ba4cf226457ea580e623b66064bd3d5949ed5eaf"
ImagesSHA1['OpenELECPi2']="90192cae3a7231f9c416da8cbbf1e03866c7dbad"
ImagesSHA1['OSMC']="baa12cde9ad97601c2fc5a1e7c11a942806ec83a"
ImagesSHA1['OSMCPi2']="5f70d2c9a7484f27b8ceb39ca8f6aa5ac6c1cfc4"
ImagesSHA1['Pidora']="00f85ca01a6555d4b0843054090c222239898b7c"
ImagesSHA1['RISCOS']="9c28ce57a23692cd70e90cfe9fa24e2014501a05"
#ImagesSHA1['RetroPi']=""
#ImagesSHA1['RetroPi2']=""
ImagesSHA1['MATE']="9964890fc6be2ac35c2cef3efcfde0687dab43a4"
#ImagesSHA1['Windows-10-IOT-Core']=""

# If the list flag has been raised, list the images
if [ $IMAGE_LIST = true ]; then
	echo "Images:"
	for i in "${!Images[@]}"
	do
		echo -e "- $COLOUR_PUR$i$COLOUR_RST"
	done
	exit
fi

#Regex
regexETag="ETag: \"([a-z0-9\-]+)\""
regexSize="Content-Length: ([0-9]+)"
regexLastMod="Last-Modified: ([a-zA-Z0-9\/ :,-]+)"
regexFileName="Content-Disposition: attachment; filename=([a-zA-Z0-9\.-]+)"
regexHTTPCode="HTTP/[0-9].[0-9] ([0-9]+) ([a-zA-Z0-9\. -]+)"

# Check the script is being run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Define the image name
IMAGE_NAME="$1"

# Check a image name was specified
if [ "$IMAGE_NAME" = "" ]; then
	echo "Please specify an image name";
	exit
fi

#Determine which image to download
IMAGE_URL="${Images[$IMAGE_NAME]}"

# Check we could find the requested image
if [ "$IMAGE_URL" = "" ]; then
	echo "Could not find an image with the name '$IMAGE_NAME'. Use the --list-images flag for a list.";
	exit
fi

#Get the device to write the image to
DEVICE_PATH="$2"

# Check a device was specified
if [ "$DEVICE_PATH" = "" ]; then
	echo "Please specify a device to write to";
	exit
fi

#Check if the device specified is a block device
if [ ! -b  "$DEVICE_PATH" ]; then
	echo "$DEVICE_PATH: Not a block device"
	exit
fi

#Check if the device is mounted
if [ `mount | grep -c "$DEVICE_PATH"` -gt 0 ]; then
	echo "$DEVICE_PATH: Unmounting all partitions"
	umount "$DEVICE_PATH"*
fi

# Check if the device is still mounted
if [ `mount | grep -c "$DEVICE_PATH"` -gt 0 ]; then
	echo "$DEVICE_PATH: Still mounted"
	exit
fi

echo -e "$COLOUR_PUR$IMAGE_NAME:$COLOUR_RST Determining if we have the latest version"

#Get the actual download URL of the image
IMAGE_URL=`curl -sIL "$IMAGE_URL" -o /dev/null -w %{url_effective}`

#Get the HTTP headers for the image
IMAGE_HEADERS=`curl -sI "$IMAGE_URL"`

#Get the HTTP response code
[[ $IMAGE_HEADERS =~ $regexHTTPCode ]]
IMAGE_RESPONSE_CODE="${BASH_REMATCH[1]}"
IMAGE_RESPONSE_MSG="${BASH_REMATCH[2]}"

if [ "$IMAGE_RESPONSE_CODE" != 200 ]; then
	echo -e "$COLOUR_PUR$IMAGE_NAME:$COLOUR_RST Download Error [HTTP $IMAGE_RESPONSE_CODE $IMAGE_RESPONSE_MSG]"
	exit
fi

#Get the date this image was last modified
[[ $IMAGE_HEADERS =~ $regexLastMod ]]
IMAGE_LASTMOD="${BASH_REMATCH[1]}"
IMAGE_LASTMOD=`date --date="$IMAGE_LASTMOD" +%s`

#Get the image size
[[ $IMAGE_HEADERS =~ $regexSize ]]
IMAGE_SIZE="${BASH_REMATCH[1]}"

#Get the image type
[[ $IMAGE_HEADERS =~ $regexType ]]
IMAGE_TYPE="${BASH_REMATCH[1]}"

#Get the image name
[[ $IMAGE_HEADERS =~ $regexFileName ]]
IMAGE_FILENAME="${BASH_REMATCH[1]}"

#Check we could found a file name
if [ "$IMAGE_FILENAME" = "" ]; then
	#default to the requested name
	IMAGE_FILENAME="$IMAGE_NAME"
fi

#Set the image paths
IMAGE_DIR="images/$IMAGE_NAME/$IMAGE_LASTMOD"
IMAGE_FILE="$IMAGE_DIR/$IMAGE_FILENAME"

#Check if we already have this version
if [ ! -f "$IMAGE_FILE" ]; then
	#Make the directory to store the image
	mkdir -p "$IMAGE_DIR"

	echo -e "$COLOUR_PUR$IMAGE_NAME:$COLOUR_RST Downloading $IMAGE_FILENAME"

	#Download the image
	curl -sL "$IMAGE_URL" | pv -s "$IMAGE_SIZE" -cN "Download" >  "$IMAGE_FILE"
else
	echo -e "$COLOUR_PUR$IMAGE_NAME:$COLOUR_RST We have the latest version of $IMAGE_FILENAME"
fi

# Check the file was created
if [ ! -f "$IMAGE_FILE" ]; then
	echo -e "$COLOUR_PUR$IMAGE_NAME:$COLOUR_RST Something went wrong.. The image wasn't downloaded"
	exit
fi

# Check if a SHA1 hash has been defined for this image
IMAGE_HASH="${ImagesSHA1[$IMAGE_NAME]}"

if [ "$IMAGE_HASH" != "" ]; then

	echo -e "$COLOUR_PUR$IMAGE_NAME:$COLOUR_RST Checking image hash"

	# Hash the downloaded image
	IMAGE_HASH_ACTUAL=$(sha1sum "$IMAGE_FILE" |  grep -Eo "^([^ ]+)")

	# Check the hashes match
	if [ "$IMAGE_HASH" != "$IMAGE_HASH_ACTUAL" ]; then
		echo -e "$COLOUR_PUR$IMAGE_NAME:$COLOUR_RST Hash mismatch! [$IMAGE_HASH != $IMAGE_HASH_ACTUAL]"
		exit 1;
	else
		echo -e "$COLOUR_PUR$IMAGE_NAME:$COLOUR_RST Image hash OK [$IMAGE_HASH]"
	fi
fi

#Get the images file type data
IMAGE_TYPE_DATA=`file "$IMAGE_FILE"`

if [[ $IMAGE_TYPE_DATA =~ "Zip archive data" ]]; then

	#Set the archive type
	IMAGE_ARCHIVE_TYPE="ZIP"

	#Set the tool used to decompress this type of archive
	IMAGE_ARCHIVE_TOOL="funzip"

	#Determine the decompressed size of the archive
	REGEX="([0-9]+)[ ]+"
	[[ `unzip -l "$IMAGE_FILE"` =~ $REGEX ]]
	IMAGE_ARCHIVE_SIZE="${BASH_REMATCH[1]}"
fi

if [[ $IMAGE_TYPE_DATA =~ "gzip compressed data" ]]; then

	#Set the archive type
	IMAGE_ARCHIVE_TYPE="GZIP"

	#Set the tool used to decompress this type of archive
	IMAGE_ARCHIVE_TOOL="zcat"

	#Determine the decompressed size of the archive
	REGEX="[ ]+[0-9]+[ ]+([0-9]+)"
	[[ `zcat -l "$IMAGE_FILE"` =~ $REGEX ]]
	IMAGE_ARCHIVE_SIZE="${BASH_REMATCH[1]}"
fi

if [[ $IMAGE_TYPE_DATA =~ "boot sector" ]]; then

	#Set the archive type
	IMAGE_ARCHIVE_TYPE="NONE"

	#Set the tool used to decompress this type of archive
	IMAGE_ARCHIVE_TOOL="NONE"
fi

if [[ $IMAGE_TYPE_DATA =~ "J_ARPI_A32FREO_EN-US_DV5" ]]; then

	#Set the archive type
	IMAGE_ARCHIVE_TYPE="ISO"

	#Set the tool used to decompress this type of archive
	IMAGE_ARCHIVE_TOOL="7z"

	#Determine the decompressed size of the archive
	REGEX="[ ]+[0-9]+[ ]+([0-9]+)"
	[[ `7z -l "$IMAGE_FILE"` =~ $REGEX ]]
	IMAGE_ARCHIVE_SIZE="${BASH_REMATCH[1]}"
fi

# Check if were able to determine what type of file the image is
if [[ "$IMAGE_ARCHIVE_TYPE" = "" ]]; then
	echo -e "$COLOUR_PUR$IMAGE_NAME:$COLOUR_RST Couldn't determine the file type of the image: '$IMAGE_TYPE_DATA'"
	exit
fi

# Check if the image is compressed
if [ "$IMAGE_ARCHIVE_TYPE" = "NONE" ]; then
	# No compression, write straight to disk
	pv -pabeWcN "Writing" "$IMAGE_FILE" | dd bs=4M of="$DEVICE_PATH" conv=fdatasync
elif [ "$IMAGE_ARCHIVE_TYPE" = "ISO" ]; then
	echo -e "$COLOUR_PUR$IMAGE_NAME:$COLOUR_RST The image is Windows, extracting ISO & MSI to IMG"
        7z x -so $IMAGE_FILE | 7z x -si
else
	echo -e "$COLOUR_PUR$IMAGE_NAME:$COLOUR_RST The image is compressed"

	# Check if the command to extract the image is avaliable
	command_exists_exit "$IMAGE_ARCHIVE_TOOL"

	# The image is compressed, write it to the disk as we're decompressing it to save time
	pv -pabeWcN "Extracting $IMAGE_ARCHIVE_TYPE" "$IMAGE_FILE" | $IMAGE_ARCHIVE_TOOL | pv -pabeWcN "Writing" -s "$IMAGE_ARCHIVE_SIZE" | dd bs=4M of="$DEVICE_PATH" conv=fdatasync
fi

# Persist any buffers
sync

# Give a complete notice
echo -e "$COLOUR_PUR$IMAGE_NAME:$COLOUR_RST Image write complete!"
