#!/bin/bash
# Bumps BUILD_NUMBER in Config.xcconfig to YYYYMMDDNN; NN is a two-digit counter that restarts at 01 each day.
# The padding keeps the number increasing across days (an unpadded 10th build, ...1610, would
# outrank the next day's first build, ...171). Allows up to 99 builds a day.
# Run as the Archive pre-action in the Medication Sidekick scheme ("source version.sh" from $SRCROOT).
cd "$SRCROOT"

current_date=$(date "+%Y%m%d")
previous_build_number=$(awk -F "=" '/^BUILD_NUMBER/ {print $2}' Config.xcconfig | tr -d ' ')
previous_date="${previous_build_number:0:8}"
counter="${previous_build_number:8}"

if [ "$current_date" = "$previous_date" ]; then
  new_counter=$((10#${counter:-0} + 1))   # 10# forces base 10 so "08"/"09" aren't read as octal
else
  new_counter=1
fi

new_build_number="${current_date}$(printf "%02d" "$new_counter")"
sed -i -e "/^BUILD_NUMBER =/ s/= .*/= $new_build_number/" Config.xcconfig
rm -f Config.xcconfig-e
