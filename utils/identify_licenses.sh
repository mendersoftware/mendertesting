#!/bin/sh

identify_licenses() {
    local LAST_COVERED="not/vendor"
    local LICENSE_FILES
    local PARENT_DIR
    local FOUND
    local ret=0
    local classifier_bin="$GOPATH/bin/identify_license"
    if [ ! -e $classifier_bin ]; then
        go get github.com/google/licenseclassifier/tools/identify_license >&2
        if [ $? != 0 ]; then
            echo "!!! Failed to install 'identify_license' binary" >&2
            return $?
        fi
    fi
    for gofile in $(find vendor -name '*.go' -type f)
    do
        if [ "${gofile::${#LAST_COVERED}}" = "${LAST_COVERED}" ]; then
            continue
        fi
        PARENT_DIR="$(dirname "$gofile")"
        FOUND=0
        while [ "$PARENT_DIR" != "vendor" ]
        do
            # Either we need to find a license file, or the file must be
            # covered by one of the license files specified in
            # KNOWN_LICENSE_FILES.
            LICENSE_FILES=$(find "$PARENT_DIR" -maxdepth 1 -iname 'LICEN[SC]E' -o -iname 'LICEN[SC]E.*' -o -iname 'COPYING')
            if [ ! -z "${LICENSE_FILES}" ]
            then
                FOUND=1
                for file in $LICENSE_FILES; do
                    LICENSE=$($classifier_bin -threshold 0.7 $file 2>/dev/null)
                    if [ $? != 0 ]; then
                        echo "??? Failed to identify license of ${file}" >&2
                    else
                        LICENSE=$(echo $LICENSE | sed 's@^'"${file}"':\ \(.\+\?\)\ (.*$@\1@')
                        echo "$(sha256sum $file) # ${LICENSE}"
                    fi
                done
                LAST_COVERED="$PARENT_DIR"
                break
            fi
            PARENT_DIR="$(dirname "$PARENT_DIR")"
        done
        if [ $FOUND != 1 ]
        then
            echo "!!! No license file to cover $gofile" >&2
            ret=1
            break
        fi
    done
    return $ret
}

USAGE="Usage: $0 [-h] [-f <FILE>]"
show_help() {
  cat << EOF
Simple utility script for generate license checksum file.

${USAGE}

Options:
        -h/--help         - Show help and exit
        -f/--file         - Generate a formatted license checksum file
EOF
}

while [ -n "$1" ]; do
  case "$1" in
    --file | -f)
      if [ -z "$2" ]; then
        show_help_and_exit_error
      fi
      output_file="$2"
      shift 2
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
    *)
      echo "Unrecognized argument: ${1}"
      echo "$USAGE"
      exit 1
      ;;
  esac
done

if [ -n "$output_file" ]; then
    identify_licenses | \
        awk '{printf "%s %s %s\n", $4, $2, $1}' | \
        sort | \
        awk '
typ != $1 {typ = $1; printf "#\n# %s\n", $1}
{printf "%s  %s\n", $3, $2}
' > $output_file
else
    identify_licenses
fi
