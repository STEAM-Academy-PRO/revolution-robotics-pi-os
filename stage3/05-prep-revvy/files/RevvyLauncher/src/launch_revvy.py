#!/bin/python3
import argparse
import json
import os
import shutil
import subprocess
import sys
import tarfile
import hashlib
import time
import traceback
from json import JSONDecodeError
from typing import List
from version import Version


default_package_dir = "default/packages"
installed_packages_dir = "user/packages"
data_directory = "user/ble"


def read_version(file):
    """Reads version from json formatted manifest file.

    Args:
        file: Path to a json formatted manifest file.

    Returns:
        A Version object containing the version json field of the provided file
        or None on error.
    """
    try:
        with open(file, "r") as mf:
            manifest = json.load(mf)
        return Version(manifest["version"])
    except FileNotFoundError:
        print(f"File not found: {file}")
    except JSONDecodeError:
        print(f"Invalid json file: {file}")
    except KeyError:
        print(f"Json file is valid but there is no version in it: {file}")

    return None


def file_hash(file):
    """Calculates the md5 hash for the file provided.

    Args:
        file: Path to the file.

    Returns:
        The md5 hash string of the file or None on error.
        E.g.: 'd41d8cd98f00b204e9800998ecf8427e'

    Raises:
        IOError: An error occurred during opening/reading the file.
    """
    try:
        hash_fn = hashlib.md5()
        with open(file, "rb") as f:
            hash_fn.update(f.read())
        return hash_fn.hexdigest()
    except IOError:
        print(f"Could not calculate hash for {file}")
        print(traceback.format_exc())
        return None


def subprocess_cmd(command):
    """Executes shell commands

    Args:
        command: Newline separated commands to be executed in the shell

    Returns:
        Return code of execution
    """
    # if we have a list, concatenate lines
    if isinstance(command, list):
        command = "\n".join(command)

    try:
        process = subprocess.Popen(
            command, stdout=subprocess.PIPE, shell=True, universal_newlines=True
        )
        for line in iter(process.stdout.readline, b""):
            sys.stdout.write(line)
            if process.poll() is not None:
                break
        return process.returncode
    except BrokenPipeError:
        return 0


def cleanup_invalid_installations(directory):
    """Removes incomplete versions of fw installations.

    The presence of the 'installed' file proves that the installation
    completed successfully. For any fw directory without this sentinel,
    we remove the directory.

    Args:
        directory: Base directory, containing installations.
    """
    print("Cleaning up interrupted installations")
    try:
        for fw_dir in os.listdir(directory):
            fw_dir = os.path.join(directory, fw_dir)
            if os.path.isdir(fw_dir):
                marker_file = os.path.join(fw_dir, "installed")
                if not os.path.isfile(marker_file):
                    print(red(f"Removing {fw_dir}: missing 'installed' marker file"))
                    shutil.rmtree(fw_dir)
    except FileNotFoundError:
        print("No user packages exist")


def has_update_package(directory, filename):
    """Checks if a valid fw update package is available.

    The '2.meta' json file contains length and md5 information about the update
    package named '2.data'. The code checks if these values are matching.

    Args:
        directory: (String) Directory path containing update package.

    Returns:
        True if update package is present and valid.
    """
    print(f"Looking for '{filename}.data' update files in {directory}")
    framework_update_file = os.path.join(directory, f"{filename}.data")
    framework_update_meta_file = os.path.join(directory, f"{filename}.meta")
    update_file_valid = False

    if os.path.isfile(framework_update_file) and os.path.isfile(
        framework_update_meta_file
    ):
        print("Found update file, validating...")
        try:
            with open(framework_update_meta_file, "r") as fup_mf:
                metadata = json.load(fup_mf)
                if metadata["length"] == os.stat(framework_update_file).st_size:
                    if (
                        metadata["md5"] is not None
                        and file_hash(framework_update_file) == metadata["md5"]
                    ):
                        update_file_valid = True
                    else:
                        print("Update file hash mismatch")
                else:
                    print("Update file length mismatch")
        except IOError:
            print("Failed to read metadata")
        except (JSONDecodeError, KeyError):
            print("Update metadata corrupted, skipping update")

        if not update_file_valid:
            os.unlink(framework_update_file)
            os.unlink(framework_update_meta_file)

    return update_file_valid


def dir_for_version(version):
    """Generates directory name for a framework version.

    Args:
        version: A Version object.

    Returns:
        Directory name as a string.
    """
    return f"revvy-{version}"


def ansi_colored(s, color):
    return f"\033[{color}m{s}\033[0m"


def red(s):
    return ansi_colored(s, "91")


def green(s):
    return ansi_colored(s, "92")


def yellow(s):
    return ansi_colored(s, "93")


def install_update_package(install_directory, filename, is_dev_package: bool):
    """Install update package.

    Extracts, validates and installs the update package. If any step of this
    process fails tries to clean up, and remove the corrupt update package.
    Installation creates a virtualenv, installs required packages via pip from
    a local repository, and places the 'installed' marker file into the
    directory, as the final step, to prove that installation finished
    successfully.

    Args:
        data_directory: Directory path containing the fw update.
        install_directory: Directory path with the fw installations.
    """
    framework_update_file = os.path.join(data_directory, f"{filename}.data")
    # We have already validated the file, in this function we just clean up the meta file
    # along with the update archive
    framework_update_meta_file = os.path.join(data_directory, f"{filename}.meta")
    tmp_dir = os.path.join(install_directory, "tmp")

    if os.path.isdir(tmp_dir):
        print(yellow(f"Removing stuck tmp dir: {tmp_dir}"))
        shutil.rmtree(tmp_dir)  # probably failed update?

    # try to extract package
    try:
        print(f"Extracting update package to: {tmp_dir}")
        with tarfile.open(framework_update_file, "r:gz") as tar:
            tar.extractall(path=tmp_dir)
    except (ValueError, tarfile.TarError):
        print("Failed to extract package")
        os.unlink(framework_update_file)
        os.unlink(framework_update_meta_file)
        return

    # try to read package version
    # integrity check done by installed package, now only get the version
    version_to_install = read_version(os.path.join(tmp_dir, "manifest.json"))

    if version_to_install is None:
        print("Failed to read package version")
        shutil.rmtree(tmp_dir)
        os.unlink(framework_update_file)
        os.unlink(framework_update_meta_file)
        return

    target_dir = os.path.join(install_directory, dir_for_version(version_to_install))
    if os.path.isdir(target_dir):
        if is_dev_package:
            print(yellow("Dev package, overwriting existing version"))
            shutil.rmtree(target_dir)
        else:
            print(yellow("Trying to install an installed version, skipping"))
            # we don't want to install this package, remove sources
            shutil.rmtree(tmp_dir)
            os.unlink(framework_update_file)
            os.unlink(framework_update_meta_file)
            return

    print(f"Installing version: {version_to_install}")
    print(f"Renaming {tmp_dir} to {target_dir}")
    shutil.move(tmp_dir, target_dir)

    print("Running setup")
    install_folder = os.path.join(target_dir, "install")
    lines = [
        'echo "Setting up venv"',
        f"python3 -m venv {target_dir}/install/venv",
        #
        'echo "Activating venv"',
        f"sh {target_dir}/install/venv/bin/activate",
        #
        'echo "Installing dependencies"',
        f"python3 -m pip install --no-cache-dir -r {install_folder}/requirements.txt --no-index --find-links file:///{install_folder}/packages",
        #
        'echo "Creating marker file"',
        f"touch {target_dir}/installed",
    ]
    subprocess_cmd(lines)

    print("Removing update package")
    os.unlink(framework_update_file)
    os.unlink(framework_update_meta_file)


def select_newest_package(directory, skipped_versions):
    """Finds latest, non blacklisted framework version.

    Checks all subdirectories in directory, reads the version information from
    the manifest.json files.

    Args:
        directory: Base directory of installed frameworks.
        skipped_versions: List of path names of framework versions to be
            skipped.

    Returns:
        String path for the newest version.
    """
    newest = Version("0.0")
    newest_path = None

    # find newest framework
    try:
        for fw_dir in os.listdir(directory):
            fw_dir = os.path.join(directory, fw_dir)
            if fw_dir in skipped_versions:
                continue

            manifest_file = os.path.join(fw_dir, "manifest.json")
            if not os.path.isfile(manifest_file):
                print(f"Manifest file not found: {manifest_file}")
                continue

            version = read_version(manifest_file)
            if version is None:
                print(f"Failed to read version from {manifest_file}")
                continue

            print(f"Found version {version}")

            if newest < version:
                newest = version
                newest_path = os.path.join(directory, dir_for_version(version))
            else:
                print(f"Skipping {version} - older than {newest}")
    except FileNotFoundError:
        print("Failed to select newest package")
        print(traceback.format_exc())

    return newest_path


# Manual exit. The loader will exit, too. Exiting with OK only makes sense if the package is
# not managed by the revvy.service.
FIRMWARE_RETURN_VALUE_OK = 0

# An error has occurred. The loader is allowed to reload this package
FIRMWARE_RETURN_VALUE_ERROR = 1

# The loader should try to load a previous package
FIRMWARE_RETURN_VALUE_INTEGRITY_ERROR = 2

# The loader should try to install and load a new package
FIRMWARE_RETURN_VALUE_UPDATE_REQUEST = 3


def run_pi_firmware(path: str):
    """Runs revvy framework in its virtualenv.

    Args:
        path: (String) Path to directory containing the revvy code.

    Returns:
        Integer error code.
        See revvy/utils.py's RevvyStatusCode for actual codes.
        0 - OK
        other - ERROR, INTEGRITY_ERROR, UPDATE_REQUEST, etc...
    """

    while True:
        print(green(f"Starting {path}"))
        lines = [
            # activate venv
            f"sh {path}/install/venv/bin/activate",
            # start script
            f"python3 -u {path}/revvy.py",
        ]
        try:
            return_value = subprocess_cmd(lines)
        except KeyboardInterrupt:
            return_value = FIRMWARE_RETURN_VALUE_OK

        print(f"Script exited with {return_value}")
        if return_value == FIRMWARE_RETURN_VALUE_ERROR:
            # if script dies with error, restart
            # TODO: maybe measure runtime and if shorter than X then disable the package
            print(yellow("Firmware exited with error, restarting"))
            continue

        return return_value


def wait_for_board_powered():
    # We use the AMP_EN pin as input to detect if the control board is on. The AMP_EN line
    # has a pullup resistor, so it's high if the board is connected and powered.
    # Due to some wiringpi weirdness, we use the header pin number for gpio mode and the
    # wiringpi pin number for reading the value. Use `gpio readall` to see the pin numbers.
    AMP_EN_HEADER_PIN = "22"
    AMP_EN_WIRINGPI_PIN = "3"

    # configure AMP_EN to input
    subprocess_cmd(f"gpio -g mode {AMP_EN_HEADER_PIN} in")

    # read AMP_EN to detect if Revvy is ON
    amp_en = subprocess.check_output(["gpio", "read", AMP_EN_WIRINGPI_PIN])
    while amp_en != b"1\n":
        print("Device is off... waiting")
        time.sleep(1)
        amp_en = subprocess.check_output(["gpio", "read", AMP_EN_WIRINGPI_PIN])


def start_newest_framework(skipped_versions: List[str]):
    """Starts the newest framework version.

    Returns True if the script should terminate, False if it should continue.
    """

    wait_for_board_powered()

    # delay to wait hciuart device
    time.sleep(1)

    print("Looking for firmware packages")
    path = select_newest_package(installed_packages_dir, skipped_versions)
    if not path:
        # if there is no such package, start the built in one
        print("No user package found, trying default")
        path = select_newest_package(default_package_dir, [])

    if not path:
        # if, for some reason there is no built-in package, stop
        print("There are no more packages to try - exit")
        return True

    return_value = run_pi_firmware(path)
    if return_value == FIRMWARE_RETURN_VALUE_OK:
        print("Manual exit, exiting loader")
        return True

    if return_value == FIRMWARE_RETURN_VALUE_INTEGRITY_ERROR:
        # if script dies with integrity error, mark the package as unstartable
        # and try the next one
        print(
            f"Integrity error or otherwise unstartable package - add {path} to skipped list"
        )
        skipped_versions.append(path)

    return False


def install_updates(install_directory):
    if has_update_package(data_directory, "pi-firmware"):
        install_update_package(install_directory, "pi-firmware", True)
    elif has_update_package(data_directory, "2"):
        install_update_package(install_directory, "2", False)


def main():
    """Runs revvy from directory.

    Handles the command line arguments of the script.

    Args:
        directory: Base directory containing installed version of the revvy
            framework.
    """
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--install-only",
        help="Install updates but do not start framework",
        action="store_true",
    )
    parser.add_argument(
        "--install-default",
        help="Install the default package. Requires --install-only"
        " and the filesystem must be writeable.",
        action="store_true",
    )

    args = parser.parse_args()

    skipped_versions = []

    if args.install_only and args.install_default:
        install_directory = default_package_dir
    else:
        install_directory = installed_packages_dir

    print(f"Install directory: {install_directory}")
    print(f"Data directory: {data_directory}")

    if args.install_only:
        cleanup_invalid_installations(install_directory)
        install_updates(install_directory)
        print("--install-only flag is set, will not start framework")
        return

    # Entering "normal" operation
    # Steps:
    # - Cleanup failed installations
    # - Search for fw update and install it
    # - Execute latest version
    # - If execution terminates normally, exit launcher
    # - If execution terminates with integrity_error, mark version as ignored and retry
    # - Otherwise restart the same version

    while True:
        cleanup_invalid_installations(install_directory)
        install_updates(install_directory)

        if start_newest_framework(skipped_versions):
            print("Exiting launcher")
            return


if __name__ == "__main__":
    current_directory = os.path.dirname(__file__)
    current_directory = os.path.abspath(current_directory)
    os.chdir(current_directory)
    main()
