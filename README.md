# Raspberry Pi Image Manager 

This tool makes it easier to download and write the latest version of an image to a device ready for use in a Raspberry Pi.
It has the added benefit as it also gives users a verbose output showing for example how long the write will take.

## Install

Instillation is easy:

    # Clone this repo
    git clone https://github.com/moebrowne/RPi-Image-Manager
    
    # Change directory
    cd RPi-Image-Manager
    
    # Set the image manager as executable
    chmod u+x manager.sh

## Usage

This tool takes 2 parameters like so:

    # Execute!
    ./manager.sh {IMAGE_NAME} {DEVICE_PATH}

Where `{IMAGE_NAME}` is one of the images listed below and `{DEVICE_PATH}` is the path to the block device you wish to write the image to

## Parameters

There is a single parameter the tool can take:

    -l or --list-images		List out all the images

## Supported Images

The following images can be installed just by using their names:

- Raspbian
- Ubuntu Snappy
- OPENELEC
- OSMC
- Pidora
- RISC OS
- Retro Pi (For RPi 1 & 2)
- Windows 10 IOT Core

## Dependencies

There is only a single package required which is non-standard; pv. It's easily installed whatever Distro you're using:

    # Ubuntu / Debian
    apt-get install pv
    
    # RHEL / CentOS
    yum install pv

### Windows

Windows has some extra dependancies

    # Install 7zip
    sudo apt-get install p7zip-full
