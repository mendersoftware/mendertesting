# Copyright 2022 Northern.tech AS
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

# mender-ci-common.sh
#
# This file defines shell helper functions to be used by any Mender pipeline.
# It is meant to be sourced directly from the GitLab CI jobs. For example:
#
#
# my-fantastic-job:
#   before_script:
#     - eval "$(curl https://raw.githubusercontent.com/mendersoftware/mendertesting/master/mender-ci-common.sh)"
#
# Read the documentation for each function for more details
#

# Usage: mender_ci_save_tmp_artifact file-to-save
#
# Saves the given file in S3 bucket temporary storage.
# For security, it computes the SHA256 checksum and saves it in
# ${CI_PROJECT_DIR}/checksums. It is responsibility of the caller to save the
# directory as part of the CI job artifacts:
#   artifacts:
#     paths:
#       - checksums
# Later jobs that will call mender_ci_load_tmp_artifact have to define "needs:"
# or "depends:" to load the checksums directory
mender_ci_save_tmp_artifact() {
    if [ -z "$1" ]; then
        echo "Usage $0 file-to-save [project-name] [pipeline-id]"
        exit 1
    fi
    user_file="$1"
    project_name=${2-$CI_PROJECT_NAME}
    pipeline_id=${3-$CI_PIPELINE_ID}
    if [ -z "$project_name" -o -z "$pipeline_id" ]; then
        echo "Could not get project-name or pipeline-id. Either set env variables or pass them as parameters"
        exit 1
    fi
    mkdir -p ${CI_PROJECT_DIR}/checksums
    sha256sum ${user_file} > ${CI_PROJECT_DIR}/checksums/$(basename ${user_file}).sha256
    env AWS_ACCESS_KEY_ID=$TMP_STORAGE_AWS_ACCESS_KEY_ID \
            AWS_SECRET_ACCESS_KEY=$TMP_STORAGE_AWS_SECRET_ACCESS_KEY \
            aws s3 cp ${user_file} s3://mender-gitlab-tmp-storage/$project_name/$pipeline_id/$(basename ${user_file})
}

# Usage: mender_ci_load_tmp_artifact file-to-load
#
# Loads the given file from S3 bucket temporary storage. It checks the SHA256
# checksum (see mender_ci_save_tmp_artifact).
mender_ci_load_tmp_artifact() {
    if [ -z "$1" ]; then
        echo "Usage $0 file-to-load [project-name] [pipeline-id]"
        exit 1
    fi
    user_file="$1"
    project_name=${2-$CI_PROJECT_NAME}
    pipeline_id=${3-$CI_PIPELINE_ID}
    if [ -z "$project_name" -o -z "$pipeline_id" ]; then
        echo "Could not get project-name or pipeline-id. Either set env variables or pass them as parameters"
        exit 1
    fi
    env AWS_ACCESS_KEY_ID=$TMP_STORAGE_AWS_ACCESS_KEY_ID \
            AWS_SECRET_ACCESS_KEY=$TMP_STORAGE_AWS_SECRET_ACCESS_KEY \
            aws s3 cp s3://mender-gitlab-tmp-storage/$project_name/$pipeline_id/$(basename ${user_file}) ${user_file}
    sha256sum -c ${CI_PROJECT_DIR}/checksums/$(basename ${user_file}).sha256
}
