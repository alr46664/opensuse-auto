#!/bin/bash
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
OPENSUSE_AUTO="$SCRIPT_DIR/../.."
UTILITIES="$OPENSUSE_AUTO/Utilities"
UTILITIES_INCLUDE="$OPENSUSE_AUTO/Utilities - Include only"

. "$UTILITIES_INCLUDE/general_functions.sh"
. "$UTILITIES_INCLUDE/cron_functions.sh"

# if it's not root, exit!
[ "$(whoami)" != "root" ] && echo -e "\n\tRUN this script as ROOT. Exiting...\n" && exit 1

get_device(){
    local DEV_UUID=$(echo $1 | tr -s ' ' | cut -d' ' -f1)
    if echo $DEV_UUID | grep -q 'UUID'; then
        local UUID=$(echo $DEV_UUID | cut -d'=' -f2)
        local DEV=$(blkid | grep $UUID | cut -d':' -f1)        
    else
        local DEV=$DEV_UUID
    fi
    local DEV=$(echo $DEV | sed -e 's@/dev/@@g')
    echo $DEV
}

# returns true (== 0) if its an SSD
is_ssd(){    
    if [ $(cat "/sys/block/$1/queue/rotational") -eq 0 ]; then
        # this value == 0 implies an SSD
        return 0
    else
        # this value == 1 implies a rotationary mechanical unit (HDD, TAPE, CD/DVD)
        return 1
    fi
}

change_to_tmpfs(){
    local MOUNTPOINT=$1
    local SIZE=$2
    local REPLACE="tmpfs  $MOUNTPOINT  tmpfs  nodev,nosuid,relatime,size=$SIZE  0  0"
    # perform the changes into the file fstab
    if grep -P " $MOUNTPOINT " /etc/fstab &> /dev/null; then
        # perform the changes into the file fstab
        sed -i -e "s@.*$MOUNTPOINT.*@$REPLACE@" /etc/fstab
    else
        echo "$REPLACE" >> /etc/fstab
    fi
}

tuning_filesystems(){    
    local FS=ext[234]
    local APPEND_OPTIONS="noatime commit=30"
    local APPEND_OPTIONS_SSD="discard"
    grep $FS /etc/fstab | while read -r line; do        
        # check for ssd
        local DEV=$(get_device "$line" | sed -e 's@[0-9]@@g')
        if is_ssd "$DEV" && [ -n "$APPEND_OPTIONS_SSD" ]; then 
            APPEND_OPTIONS="$APPEND_OPTIONS $APPEND_OPTIONS_SSD"
        fi
        # 
        local REPLACE="$line"
        # get all options and filter them out of append_options 
        local OPTIONS=$(echo $line | tr -s " " | cut -d' ' -f4 | tr ',' ' ')        
        for op in $OPTIONS; do        
            APPEND_OPTIONS=$(echo $APPEND_OPTIONS | sed -e "s@$op@@" | tr -s ' ' | xargs)
        done
        # restore options back into comma separation
        APPEND_OPTIONS=$(echo "$OPTIONS $APPEND_OPTIONS")
        OPTIONS=$(echo $OPTIONS | tr ' ' ',')
        APPEND_OPTIONS=$(echo $APPEND_OPTIONS | tr -s ' ' | tr ' ' ',' | sed -e 's@[,]\{2,\}@@g')
        # replace the options in the variable
        REPLACE=$(echo $REPLACE | sed -e "s/$OPTIONS/$APPEND_OPTIONS/")
        # perform the changes into the file fstab
        sed -i -e "s@$line@$REPLACE@" /etc/fstab
    done
}

tuning_tmpfs(){
   change_to_tmpfs '/tmp' '50M' &&
   change_to_tmpfs '/var/log' '512M'
}

# this makes the filesystems mounted at boot in /etc/fstab to run with no_atime
tuning_filesystems &&
tuning_tmpfs 
