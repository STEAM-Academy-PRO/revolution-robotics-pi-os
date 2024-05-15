#!/bin/bash -e

if [ "${NO_PRERUN_QCOW2}" = "0" ]; then
	IMG_FILE="${STAGE_WORK_DIR}/${IMG_FILENAME}${IMG_SUFFIX}.img"

	unmount_image "${IMG_FILE}"

	rm -f "${IMG_FILE}"

	rm -rf "${ROOTFS_DIR}"
	mkdir -p "${ROOTFS_DIR}"

	BOOT_SIZE="$((512 * 1024 * 1024))"
	ROOT_SIZE=$(du --apparent-size -s "${EXPORT_ROOTFS_DIR}" --exclude var/cache/apt/archives --exclude boot --exclude home/pi/RevvyFramework/user --block-size=1 | cut -f 1)
	DATA_SIZE="$((1024 * 1024 * 1024 * 2))"

	# All partition sizes and starts will be aligned to this size
	ALIGN="$((4 * 1024 * 1024))"
	# Add this much space to the calculated file size. This allows for
	# some overhead (since actual space usage is usually rounded up to the
	# filesystem block size) and gives some free space on the resulting
	# image.
	ROOT_MARGIN="$(echo "($ROOT_SIZE * 0.2 + 256 * 1024 * 1024) / 1" | bc)"

	BOOT_PART_START=$((ALIGN))
	BOOT_PART_SIZE=$(((BOOT_SIZE + ALIGN - 1) / ALIGN * ALIGN))
	ROOT_PART_START=$((BOOT_PART_START + BOOT_PART_SIZE))
	ROOT_PART_SIZE=$(((ROOT_SIZE + ROOT_MARGIN + ALIGN  - 1) / ALIGN * ALIGN))
	DATA_PART_START=$((ROOT_PART_START + ROOT_PART_SIZE))
	DATA_PART_SIZE=$(((DATA_SIZE + ALIGN - 1) / ALIGN * ALIGN))
	IMG_SIZE=$((BOOT_PART_START + BOOT_PART_SIZE + ROOT_PART_SIZE + DATA_PART_SIZE))

	truncate -s "${IMG_SIZE}" "${IMG_FILE}"

	parted --script "${IMG_FILE}" mklabel msdos
	parted --script "${IMG_FILE}" unit B mkpart primary fat32 "${BOOT_PART_START}" "$((BOOT_PART_START + BOOT_PART_SIZE - 1))"
	parted --script "${IMG_FILE}" unit B mkpart primary ext4 "${ROOT_PART_START}" "$((ROOT_PART_START + ROOT_PART_SIZE - 1))"
	parted --script "${IMG_FILE}" unit B mkpart primary ext4 "${DATA_PART_START}" "$((DATA_PART_START + DATA_PART_SIZE - 1))"

	echo "Creating loop device..."
	cnt=0
	until ensure_next_loopdev && LOOP_DEV="$(losetup --show --find --partscan "$IMG_FILE")"; do
		if [ $cnt -lt 5 ]; then
			cnt=$((cnt + 1))
			echo "Error in losetup.  Retrying..."
			sleep 5
		else
			echo "ERROR: losetup failed; exiting"
			exit 1
		fi
	done

	ensure_loopdev_partitions "$LOOP_DEV"
	BOOT_DEV="${LOOP_DEV}p1"
	ROOT_DEV="${LOOP_DEV}p2"
	DATA_DEV="${LOOP_DEV}p3"

	echo "/boot: offset $BOOT_OFFSET, length $BOOT_LENGTH"
	echo "/:     offset $ROOT_OFFSET, length $ROOT_LENGTH"
	echo "/home/pi/RevvyFramework/user:     offset $DATA_OFFSET, length $DATA_LENGTH"

	ROOT_FEATURES="^huge_file"
	for FEATURE in 64bit; do
	if grep -q "$FEATURE" /etc/mke2fs.conf; then
		ROOT_FEATURES="^$FEATURE,$ROOT_FEATURES"
	fi
	done
	DATA_FEATURES="$ROOT_FEATURES"

	mkdosfs -n bootfs -F 32 -s 4 -v "$BOOT_DEV" > /dev/null
	mkfs.ext4 -L rootfs -O "$ROOT_FEATURES" "$ROOT_DEV" > /dev/null
	mkfs.ext4 -L data -O "$DATA_FEATURES" "$DATA_DEV" > /dev/null

	mount -v "$ROOT_DEV" "${ROOTFS_DIR}" -t ext4
	mkdir -p "${ROOTFS_DIR}/boot/firmware"
	mount -v "$BOOT_DEV" "${ROOTFS_DIR}/boot/firmware" -t vfat
	mkdir -p "${ROOTFS_DIR}/home/pi/RevvyFramework/user"
	mount -v "$DATA_DEV" "${ROOTFS_DIR}/home/pi/RevvyFramework/user" -t ext4

	rsync -aHAXx --exclude /var/cache/apt/archives --exclude /boot/firmware --exclude home/pi/RevvyFramework/user "${EXPORT_ROOTFS_DIR}/" "${ROOTFS_DIR}/"
	rsync -rtx "${EXPORT_ROOTFS_DIR}/boot/firmware" "${ROOTFS_DIR}/boot/firmware"
	rsync -aHAXx "${EXPORT_ROOTFS_DIR}/home/pi/RevvyFramework/user/" "${ROOTFS_DIR}/home/pi/RevvyFramework/user/"
fi
