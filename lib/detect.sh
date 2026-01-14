#!/bin/bash
# detect.sh - Drive and filesystem detection
# Provides: detect_filesystem, detect_drive

detect_filesystem() {
  FILESYSTEMPARTITION=""
  if command -v lsblk &> /dev/null; then
    FILESYSTEMPARTITION=$(lsblk -P 2>/dev/null | grep "$TARGET" | head -n 1 | awk '{print $1}' | cut -d"=" -f2 | cut -d"\"" -f2)
  fi
  if [ -z "$FILESYSTEMPARTITION" ] && command -v findmnt &> /dev/null; then
    FILESYSTEMPARTITION=$(findmnt -n -o SOURCE "$TARGET" 2>/dev/null | sed 's|/dev/||')
  fi
  if [ -z "$FILESYSTEMPARTITION" ]; then
    FILESYSTEMPARTITION=$(df "$TARGET" 2>/dev/null | tail +2 | awk '{print $1}' | sed 's|/dev/||')
  fi

  FILESYSTEMTYPE=$(df -T "$TARGET" | tail +2 | awk '{print $2}')
  FILESYSTEMSIZE=$(df -Th "$TARGET" | tail +2 | awk '{print $3}')
}

detect_drive_type() {
  ISOVERLAY=0
  ISTMPFS=0
  ISNVME=0
  ISEMMC=0
  ISMDADM=0
  DRIVE=""
  DRIVEDETAILS=""

  if [[ "$FILESYSTEMTYPE" == overlay ]]; then
    ISOVERLAY=1
  elif [[ "$FILESYSTEMTYPE" == tmpfs ]]; then
    ISTMPFS=1
  elif [[ "$FILESYSTEMPARTITION" == mmcblk* ]]; then
    DRIVE=$(echo $FILESYSTEMPARTITION | rev | cut -c 3- | rev)
    ISEMMC=1
  elif [[ "$FILESYSTEMPARTITION" == nvme* ]]; then
    DRIVE=$(echo $FILESYSTEMPARTITION | rev | cut -c 3- | rev)
    ISNVME=1
  elif [[ "$FILESYSTEMPARTITION" == hd* ]] || [[ "$FILESYSTEMPARTITION" == sd* ]] || [[ "$FILESYSTEMPARTITION" == vd* ]]; then
    DRIVE=$(echo $FILESYSTEMPARTITION | sed 's/[0-9]*$//')
  elif [[ "$FILESYSTEMPARTITION" == md* ]]; then
    DRIVE=$FILESYSTEMPARTITION
    ISMDADM=1
  fi
}

detect_drive_info() {
  DRIVELABEL="Drive"
  DRIVENAME="Unknown"
  DRIVESIZE="Unknown"

  if [ $ISOVERLAY -eq 1 ]; then
    DRIVENAME="Overlay"
    DRIVE="overlay"
    DRIVESIZE=$FILESYSTEMSIZE
  elif [ $ISTMPFS -eq 1 ]; then
    DRIVENAME="RAM"
    DRIVE="tmpfs"
    DRIVESIZE=$(free -h --si | grep Mem: | awk '{print $2}')
  elif [ $ISEMMC -eq 1 ]; then
    DEVICE=()
    if [ -f /sys/block/$DRIVE/device/type ]; then
      case "$(cat /sys/block/$DRIVE/device/type)" in
        SD) DEVICE+=("SD Card");;
        *) DEVICE+=();;
      esac
    fi
    [ -f /sys/block/$DRIVE/device/name ] && DEVICE+=($(cat /sys/block/$DRIVE/device/name | sed 's/ *$//g'))
    DRIVENAME=${DEVICE[@]:-"eMMC flash storage"}
    DRIVESIZE=$(fromBytes $(($(cat /sys/block/$DRIVE/size) * 512)))
  elif [ $ISMDADM -eq 1 ]; then
    DRIVELABEL="Drives"
    DRIVENAME="mdadm $(cat /sys/block/$DRIVE/md/level)"
    DRIVESIZE=$(fromBytes $(($(cat /sys/block/$DRIVE/size) * 512)))
    DISKS=$(ls /sys/block/$DRIVE/slaves/)
    DRIVEDETAILS="using $(echo $DISKS | wc -w) disks ($(echo $DISKS | sed 's/ /, /g'))"
  elif [ -n "$DRIVE" ] && [ -d /sys/block/$DRIVE/device ]; then
    DEVICE=()
    [ -f /sys/block/$DRIVE/device/vendor ] && DEVICE+=($(cat /sys/block/$DRIVE/device/vendor | sed 's/ *$//g'))
    [ -f /sys/block/$DRIVE/device/model ] && DEVICE+=($(cat /sys/block/$DRIVE/device/model | sed 's/ *$//g'))
    DRIVENAME=${DEVICE[@]:-"Unknown drive"}
    DRIVESIZE=$(fromBytes $(($(cat /sys/block/$DRIVE/size) * 512)))
  else
    DRIVE="Unknown"
  fi

  if [ "$DRIVE" = "Unknown" ]; then
    DRIVEINFO="Unknown"
  else
    DRIVEINFO="$DRIVENAME ($DRIVE, $DRIVESIZE) $DRIVEDETAILS"
  fi
}

detect_all() {
  detect_filesystem
  detect_drive_type
  detect_drive_info
}
