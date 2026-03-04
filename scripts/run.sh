#!/bin/bash
APP="$HOME/Applications/ListenType.app"
if [ ! -d "$APP" ]; then
    echo "ListenType.app not found. Run scripts/build.sh first."
    exit 1
fi
open "$APP"
