#!/bin/bash
set -euo pipefail

project_dir=$(cd "$(dirname "$0")/.." && pwd)
service_name='Downscale Images.workflow'
service_dir="$HOME/Library/Services"

/usr/bin/python3 "$project_dir/scripts/build_workflow.py"
/usr/bin/plutil -lint "$project_dir/dist/$service_name/Contents/Info.plist"
/usr/bin/plutil -lint "$project_dir/dist/$service_name/Contents/document.wflow"
mkdir -p "$service_dir"
/usr/bin/ditto "$project_dir/dist/$service_name" "$service_dir/$service_name"
/usr/bin/python3 "$project_dir/scripts/enable_quick_action.py"
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true
/System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true

echo "Installed Finder Quick Action: $service_dir/$service_name"
echo 'If Finder does not show it immediately, relaunch Finder or log out and back in.'
