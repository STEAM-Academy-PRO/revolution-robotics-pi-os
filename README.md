# BakeRPi

_Tool used to create the RPi image for Revvy_

## Usage

Simply set the image name, and run the Docker builder:

```bash
$ echo "IMG_NAME=revvy" > config
$ ./build-docker.sh 
```

The revvy image will be in the deploy folder.

### Known issues

Execution sometimes failes during the export phase, as losetup is failing in the
background. In this case, you should simply rerun the command, in the following way:

```bash
$ CONTINUE=1 ./build-docker.sh
```

This will just retry the process, while skipping the already completed operations
of the first few stages.

## Roots

This tool is based on https://github.com/RPi-Distro/pi-gen. We basically removed
anything after stage2 (lite version of Raspbian).

For details about the configuration parameters, or what the original steps do,
please consult the pi-gen repo.
