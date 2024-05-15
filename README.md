# Pi OS builder

Based on `pi-gen` rev `3b5e214f5ec4e23323bdd489b999536c487fcd12`

## Config

Upon execution, `build.sh` will source the file `config` in the current
working directory.  This bash shell fragment is intended to set needed
environment variables.

The following environment variables are supported:

 * `IMG_NAME` **required** (Default: unset)

   The name of the image to build with the current stage directories. Use this
   variable to set the root name of your OS, eg `IMG_NAME=Frobulator`.
   Export files in stages may add suffixes to `IMG_NAME`.

 * `RELEASE` (Default: bookworm)

   The release version to build images against. Valid values are any supported
   Debian release. However, since different releases will have different sets of
   packages available, you'll need to either modify your stages accordingly, or
   checkout the appropriate branch. For example, if you'd like to build a
   `bullseye` image, you should do so from the `bullseye` branch.

 * `APT_PROXY` (Default: unset)

   If you require the use of an apt proxy, set it here.  This proxy setting
   will not be included in the image, making it safe to use an `apt-cacher` or
   similar package for development.

 * `BASE_DIR`  (Default: location of `build.sh`)

   **CAUTION**: Currently, changing this value will probably break build.sh

   Top-level directory for `pi-gen`.  Contains stage directories, build
   scripts, and by default both work and deployment directories.

 * `WORK_DIR`  (Default: `"$BASE_DIR/work"`)

   Directory in which `pi-gen` builds the target system.  This value can be
   changed if you have a suitably large, fast storage location for stages to
   be built and cached.  Note, `WORK_DIR` stores a complete copy of the target
   system for each build stage, amounting to tens of gigabytes in the case of
   Raspbian.

   **CAUTION**: If your working directory is on an NTFS partition you probably won't be able to build: make sure this is a proper Linux filesystem.

 * `DEPLOY_DIR`  (Default: `"$BASE_DIR/deploy"`)

   Output directory for target system images and NOOBS bundles.

 * `DEPLOY_COMPRESSION` (Default: `zip`)

   Set to:
   * `none` to deploy the actual image (`.img`).
   * `zip` to deploy a zipped image (`.zip`).
   * `gz` to deploy a gzipped image (`.img.gz`).
   * `xz` to deploy a xzipped image (`.img.xz`).


 * `DEPLOY_ZIP` (Deprecated)

   This option has been deprecated in favor of `DEPLOY_COMPRESSION`.

   If `DEPLOY_ZIP=0` is still present in your config file, the behavior is the
   same as with `DEPLOY_COMPRESSION=none`.

 * `COMPRESSION_LEVEL` (Default: `6`)

   Compression level to be used when using `zip`, `gz` or `xz` for
   `DEPLOY_COMPRESSION`. From 0 to 9 (refer to the tool man page for more
   information on this. Usually 0 is no compression but very fast, up to 9 with
   the best compression but very slow ).

 * `USE_QEMU` (Default: `"0"`)

   Setting to '1' enables the QEMU mode - creating an image that can be mounted via QEMU for an emulated
   environment. These images include "-qemu" in the image file name.

 * `LOCALE_DEFAULT` (Default: "en_GB.UTF-8" )

   Default system locale.

 * `TARGET_HOSTNAME` (Default: "raspberrypi" )

   Setting the hostname to the specified value.

 * `KEYBOARD_KEYMAP` (Default: "gb" )

   Default keyboard keymap.

   To get the current value from a running system, run `debconf-show
   keyboard-configuration` and look at the
   `keyboard-configuration/xkb-keymap` value.

 * `KEYBOARD_LAYOUT` (Default: "English (UK)" )

   Default keyboard layout.

   To get the current value from a running system, run `debconf-show
   keyboard-configuration` and look at the
   `keyboard-configuration/variant` value.

 * `TIMEZONE_DEFAULT` (Default: "Europe/London" )

   Default keyboard layout.

   To get the current value from a running system, look in
   `/etc/timezone`.

 * `FIRST_USER_NAME` (Default: `pi`)

   Username for the first user.

 * `FIRST_USER_PASS` (Default: unset)

   Password for the first user. If unset, the account is locked.

 * `WPA_COUNTRY` (Default: unset)

   Sets the default WLAN regulatory domain and unblocks WLAN interfaces. This should be a 2-letter ISO/IEC 3166 country Code, i.e. `GB`

 * `ENABLE_SSH` (Default: `0`)

   Setting to `1` will enable ssh server for remote log in. Note that if you are using a common password such as the defaults there is a high risk of attackers taking over you Raspberry Pi.

  * `PUBKEY_SSH_FIRST_USER` (Default: unset)

   Setting this to a value will make that value the contents of the FIRST_USER_NAME's ~/.ssh/authorized_keys.  Obviously the value should
   therefore be a valid authorized_keys file.  Note that this does not
   automatically enable SSH.

  * `PUBKEY_ONLY_SSH` (Default: `0`)

   * Setting to `1` will disable password authentication for SSH and enable
   public key authentication.  Note that if SSH is not enabled this will take
   effect when SSH becomes enabled.

 * `SETFCAP` (Default: unset)

   * Setting to `1` will prevent pi-gen from dropping the "capabilities"
   feature. Generating the root filesystem with capabilities enabled and running
   it from a filesystem that does not support capabilities (like NFS) can cause
   issues. Only enable this if you understand what it is.

 * `STAGE_LIST` (Default: `stage*`)

    If set, then instead of working through the numeric stages in order, this list will be followed. For example setting to `"stage0 stage1 mystage stage2"` will run the contents of `mystage` before stage2. Note that quotes are needed around the list. An absolute or relative path can be given for stages outside the pi-gen directory.

 * `FIRMWARE_RELEASE`: the tag name of the pi-firmware release to be included. Mutually exclusive with
   `FIRMWARE_REV`.

 * `FIRMWARE_REV`: the git commit hash of the pi-firmware package to be included. Mutually exclusive with
   `FIRWAMRE_RELEASE`. Using a revision will NOT include the MCU firmware and is recommended only for testing.

The config file can also be specified on the command line as an argument the `build.sh` or `build-docker.sh` scripts.

```
./build.sh -c myconfig
```

This is parsed after `config` so can be used to override values set there.

## How the build process works

The following process is followed to build images:

 * Loop through all of the stage directories in alphanumeric order

 * Move on to the next directory if this stage directory contains a file called
   "SKIP"

 * Run the script ```prerun.sh``` which is generally just used to copy the build
   directory between stages.

 * In each stage directory loop through each subdirectory and then run each of the
   install scripts it contains, again in alphanumeric order. These need to be named
   with a two digit padded number at the beginning.
   There are a number of different files and directories which can be used to
   control different parts of the build process:

     - **00-run.sh** - A unix shell script. Needs to be made executable for it to run.

     - **00-run-chroot.sh** - A unix shell script which will be run in the chroot
       of the image build directory. Needs to be made executable for it to run.

     - **00-debconf** - Contents of this file are passed to debconf-set-selections
       to configure things like locale, etc.

     - **00-packages** - A list of packages to install. Can have more than one, space
       separated, per line.

     - **00-packages-nr** - As 00-packages, except these will be installed using
       the ```--no-install-recommends -y``` parameters to apt-get.

     - **00-patches** - A directory containing patch files to be applied, using quilt.
       If a file named 'EDIT' is present in the directory, the build process will
       be interrupted with a bash session, allowing an opportunity to create/revise
       the patches.

  * If the stage directory contains files called "EXPORT_NOOBS" or "EXPORT_IMAGE" then
    add this stage to a list of images to generate

  * Generate the images for any stages that have specified them

It is recommended to examine build.sh for finer details.
