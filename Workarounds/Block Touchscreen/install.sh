 #!/bin/bash
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
OPENSUSE_AUTO="$SCRIPT_DIR/../.."
UTILITIES="$OPENSUSE_AUTO/Utilities"
UTILITIES_INCLUDE="$OPENSUSE_AUTO/Utilities - Include only"

# load cron functions
. "$UTILITIES_INCLUDE/modprobe_functions.sh"

blacklist_module "hid_multitouch" "50-blacklist-touch.conf"