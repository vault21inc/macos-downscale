#!/bin/bash
# Finder passes selected image paths as separate arguments.
set -uo pipefail

DEFAULT_MAX_PIXELS=1920
MAX_ALLOWED_PIXELS=30000

show_error() {
  local message=$1
  printf 'Downscale Images: %s\n' "$message" >&2
  if [[ ${headless:-false} == false ]]; then
    /usr/bin/osascript - "$message" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  display alert "Downscale Images" message (item 1 of argv) as warning
end run
APPLESCRIPT
  fi
}

headless=false
if [[ ${1-} == --max-pixels ]]; then
  headless=true
  if (( $# < 3 )); then
    show_error 'Usage: downscale.sh --max-pixels NUMBER IMAGE...'
    exit 2
  fi
  max_pixels=$2
  shift 2
else
  if (( $# == 0 )); then
    show_error 'Select one or more images in Finder.'
    exit 2
  fi
  max_pixels=$(/usr/bin/osascript - "$DEFAULT_MAX_PIXELS" <<'APPLESCRIPT'
on run argv
  try
    set answer to display dialog "Maximum width or height in pixels. Smaller images will be skipped." default answer (item 1 of argv) buttons {"Cancel", "Downscale"} default button "Downscale" with title "Downscale Images"
    return text returned of answer
  on error number -128
    return "__CANCELLED__"
  end try
end run
APPLESCRIPT
  ) || exit 1
  [[ $max_pixels == __CANCELLED__ ]] && exit 0
fi

if [[ ! $max_pixels =~ ^[0-9]{1,5}$ ]]; then
  show_error "Enter a whole number from 1 to $MAX_ALLOWED_PIXELS."
  exit 2
fi
max_pixels=$((10#$max_pixels))
if (( max_pixels < 1 || max_pixels > MAX_ALLOWED_PIXELS )); then
  show_error "Enter a whole number from 1 to $MAX_ALLOWED_PIXELS."
  exit 2
fi

created=0
skipped=0
failed=0
failures=()
parent_directories=()
output_directories=()

for source in "$@"; do
  if [[ ! -f $source ]]; then
    failures+=("${source##*/}: not a file")
    ((failed += 1))
    continue
  fi

  dimensions=$(/usr/bin/sips -g pixelWidth -g pixelHeight "$source" 2>&1)
  if (( $? != 0 )); then
    failures+=("${source##*/}: unreadable image")
    ((failed += 1))
    continue
  fi
  width=$(printf '%s\n' "$dimensions" | /usr/bin/awk '$1 == "pixelWidth:" { print $2; exit }')
  height=$(printf '%s\n' "$dimensions" | /usr/bin/awk '$1 == "pixelHeight:" { print $2; exit }')
  if [[ ! $width =~ ^[0-9]+$ || ! $height =~ ^[0-9]+$ ]] ||
     (( width < 1 || height < 1 )); then
    failures+=("${source##*/}: dimensions unavailable")
    ((failed += 1))
    continue
  fi
  if (( width <= max_pixels && height <= max_pixels )); then
    printf 'SKIPPED (already within limit): %s\n' "$source"
    ((skipped += 1))
    continue
  fi

  if [[ $source == */* ]]; then
    directory=${source%/*}
    [[ -n $directory ]] || directory=/
  else
    directory=.
  fi
  filename=${source##*/}
  stem=${filename%.*}
  if [[ $filename == *.* && -n $stem ]]; then
    extension=.${filename##*.}
  else
    stem=$filename
    extension=.png
  fi

  output_directory=''
  for index in "${!parent_directories[@]}"; do
    if [[ ${parent_directories[$index]} == "$directory" ]]; then
      output_directory=${output_directories[$index]}
      break
    fi
  done
  if [[ -z $output_directory ]]; then
    while :; do
      timestamp=$(/bin/date '+%Y-%m-%d_%H-%M-%S')
      candidate_directory="$directory/$timestamp"
      if [[ -e $candidate_directory || -L $candidate_directory ]]; then
        /bin/sleep 1
        continue
      fi
      if /bin/mkdir "$candidate_directory" 2>/dev/null; then
        output_directory=$candidate_directory
        parent_directories+=("$directory")
        output_directories+=("$output_directory")
        break
      fi
      if [[ -e $candidate_directory || -L $candidate_directory ]]; then
        /bin/sleep 1
        continue
      fi
      failures+=("$filename: could not create output folder")
      ((failed += 1))
      break
    done
    [[ -n $output_directory ]] || continue
  fi

  base="$output_directory/$stem-${max_pixels}px"
  temporary="$output_directory/.$stem-downscale-$(/usr/bin/uuidgen)$extension"
  if [[ $filename == "$stem" ]]; then
    output_log=$(/usr/bin/sips -s format png -Z "$max_pixels" "$source" --out "$temporary" 2>&1)
  else
    output_log=$(/usr/bin/sips -Z "$max_pixels" "$source" --out "$temporary" 2>&1)
  fi
  if (( $? != 0 )) || [[ ! -f $temporary ]]; then
    /bin/rm -f "$temporary"
    failures+=("$filename: sips could not create a resized copy")
    ((failed += 1))
    printf 'FAILED: %s\n%s\n' "$source" "$output_log" >&2
    continue
  fi

  resized=$(/usr/bin/sips -g pixelWidth -g pixelHeight "$temporary" 2>&1)
  resized_width=$(printf '%s\n' "$resized" | /usr/bin/awk '$1 == "pixelWidth:" { print $2; exit }')
  resized_height=$(printf '%s\n' "$resized" | /usr/bin/awk '$1 == "pixelHeight:" { print $2; exit }')
  if [[ ! $resized_width =~ ^[0-9]+$ || ! $resized_height =~ ^[0-9]+$ ]] ||
     (( resized_width < 1 || resized_height < 1 ||
        resized_width > max_pixels || resized_height > max_pixels )); then
    /bin/rm -f "$temporary"
    failures+=("$filename: resized dimensions could not be verified")
    ((failed += 1))
    continue
  fi

  suffix=1
  while :; do
    if (( suffix == 1 )); then
      destination="$base$extension"
    else
      destination="$base-$suffix$extension"
    fi
    if [[ -e $destination || -L $destination ]]; then
      ((suffix += 1))
      continue
    fi
    if ! /bin/mv -n "$temporary" "$destination"; then
      /bin/rm -f "$temporary"
      failures+=("$filename: could not save the resized copy")
      ((failed += 1))
      break
    fi
    if [[ ! -e $temporary ]]; then
      printf 'CREATED: %s\n' "$destination"
      ((created += 1))
      break
    fi
    ((suffix += 1))
  done
done

if (( ${#output_directories[@]} > 0 )); then
  for output_directory in "${output_directories[@]}"; do
    /bin/rmdir "$output_directory" 2>/dev/null || true
  done
fi

printf 'Created: %d; skipped: %d; failed: %d\n' "$created" "$skipped" "$failed"
if [[ $headless == false ]]; then
  details=''
  if (( failed > 0 )); then
    details=$(printf '%s\n' "${failures[@]:0:3}")
  fi
  /usr/bin/osascript - "$created" "$skipped" "$failed" "$details" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  set summary to "Created " & (item 1 of argv) & " resized copies. " & (item 2 of argv) & " already within limit. " & (item 3 of argv) & " failed."
  if (item 4 of argv) is not "" then set summary to summary & return & return & (item 4 of argv)
  display dialog summary buttons {"OK"} default button "OK" with title "Downscale Images"
end run
APPLESCRIPT
  exit 0
fi

(( failed == 0 ))
