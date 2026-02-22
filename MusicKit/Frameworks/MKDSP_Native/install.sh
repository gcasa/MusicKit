#!/bin/sh
. /usr/GNUstep/System/Library/Makefiles/GNUstep.sh && make GNUSTEP_INSTALLATION_DOMAIN=LOCAL debug=yes install && echo "---" && date && echo "---"
