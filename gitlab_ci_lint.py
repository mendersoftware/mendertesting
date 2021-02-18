#!/usr/bin/env python3
# Copyright 2021 Northern.tech AS
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

import os
import sys
import requests
import json

THIS_DIR = os.path.dirname(os.path.abspath(__file__))

INVALID_KNOWN_FILES = [
    ".gitlab-ci.yml",  # Local file `.gitlab-ci-check-commits.yml` does not have project!
    ".gitlab-ci-template-k8s-test.yml",  # jobs config should contain at least one visible job
]


def lint_file(file):
    """Lints GitLab CI file. Returns True on success"""
    with open(file) as f:
        r = requests.post(
            "https://gitlab.com/api/v4/ci/lint",
            json={"content": f.read()},
            verify=False,
        )

    if r.status_code != requests.codes["OK"]:
        print("POST returned status code %d" % r.status_code)
        return False

    data = r.json()
    if data["status"] != "valid":
        print("File %s returned the following errors:" % file)
        for error in data["errors"]:
            print(error)
        return False

    return True


def main():

    success = True
    for file in os.listdir(THIS_DIR):
        if file.endswith(".yml") and not file in INVALID_KNOWN_FILES:
            if not lint_file(file):
                success = False

    if not success:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
