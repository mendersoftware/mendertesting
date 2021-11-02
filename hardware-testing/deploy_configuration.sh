#!/bin/bash
deviceid="$1"
image="$2"
server_url=${SERVER_URL:-"https://hosted.mender.io"}

[[ "${deviceid}" == "" || "${image}" == "" ]] && exit 1
[ "${AUTH_TOKEN}" == "" ] && exit 2

curl -v -XPUT -H "Content-Type: application/json;" -H "Authorization: Bearer ${AUTH_TOKEN}" -d "{\"image\":\"${image}\"}" "${server_url}/api/management/v1/deviceconfig/configurations/device/${deviceid}"
curl -v -XGET -H "Content-Type: application/json;" -H "Authorization: Bearer ${AUTH_TOKEN}" "${server_url}/api/management/v1/deviceconfig/configurations/device/${deviceid}" | jq .
curl -v -XPOST -H "Content-Type: application/json;" -H "Authorization: Bearer ${AUTH_TOKEN}" -d '{"retries":0}' "${server_url}/api/management/v1/deviceconfig/configurations/device/${deviceid}/deploy"
