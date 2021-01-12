#!/usr/bin/env python3
# Copyright 2020 Northern.tech AS
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
import requests

THIS_DIR = os.path.dirname(os.path.abspath(__file__))

def main():
    pid = os.getenv("UPSTREAM_PIPELINE_ID")
    token = os.getenv("GITLAB_TOKEN")

    if pid == "":
        raise RuntimeError("UPSTREAM_PIPELINE_ID not provided, aborting")
    if token == "":
        raise RuntimeError("GITLAB_TOKEN not provided, aborting")

    # get upstream pipeline jobs
    res = requests.get("https://gitlab.com/api/v4/projects/13172542/pipelines/{}/jobs".format(pid), headers = {'PRIVATE-TOKEN': token})
    if res.status_code != 200:
        raise RuntimeError(str(res) + ", aborting")

    # find job by name
    res = res.json()
    job = [r for r in res if r["name"] == "build:testing"]
    assert(len(job) == 1)
    job = job[0]

    # get art by job id / art name
    res = requests.get("https://gitlab.com/api/v4/projects/13172542/jobs/{}/artifacts/testingImage.tar".format(job["id"]), headers = {'PRIVATE-TOKEN': token})
    if res.status_code != 200:
        raise RuntimeError(str(res) + ", aborting")

    art_path = "/tmp/mendertesting/testingImage.tar"
    f = open(art_path,"wb+")
    f.write(res.content)
    f.close()


if __name__ == "__main__":
    main()
