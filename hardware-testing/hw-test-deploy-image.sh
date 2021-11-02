#!/bin/bash

export PATH=${PATH}:/home/mender-test-bot/.local/bin
image=$(cat "$1" | jq -r .image)
images_directory=${HW_TESTING_IMAGES_DIRECTORY:-"/data/images"}
slave_control=${HW_TESTING_SLAVE_CONTROL:-"/home/mender-test-bot/slave-control"}
output_device=${HW_TESTING_TARGET_DEVICE:-"/dev/sda"}
wget_command="wget -q"

[[ "$image" == "" || "${image}" == "-" ]] && exit 0

function cleanup() {
  [[ "${image}" != "" && "${image}" != "-" ]] && rm -f "${image}"
}

trap cleanup EXIT SIGQUIT SIGTERM

if [ ! -d "${images_directory}" ]; then
  echo "ERROR: directory ${images_directory} does not exist"
  exit 1
fi

cd "${images_directory}"
if [ $? -ne 0  ]; then
  echo "ERROR: directory ${images_directory} does not exist"
  exit 1
fi

[ -f "${image}" ] && rm -f "${image}"
$wget_command "$image"
if [ $? -ne 0  ]; then
  echo "ERROR: cant get ${image}."
  exit 1
fi

image_file=$(basename "$image")

"$slave_control" mode flash
if [ $? -ne 0  ]; then
  echo "ERROR: cant switch the device to flash mode."
  exit 1
fi

rc=0
if [ "${image_file##*.}" == "xz" ]; then
  xzcat "${image_file}" | dd of=/dev/sda bs=8192
  rc=$?
else
  dd of="${output_device}" if="${image_file}" bs=8192
  rc=$?
fi
if [ $rc -ne 0  ]; then
  echo "ERROR: failed to write to $output_device."
  exit 1
fi

"$slave_control" mode test
if [ $? -ne 0  ]; then
  echo "ERROR: cant switch the device to test mode."
  exit 1
fi

rm -f "${image}"
