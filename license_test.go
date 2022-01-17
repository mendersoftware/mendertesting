// Copyright 2022 Northern.tech AS
//
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.

package mendertesting

import (
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func resetKnownLicenses() {
	known_license_files = []string{}
}

func TestMockLicenses(t *testing.T) {
	hierarchy := path.Join("tmp/src", packageLocation)

	// Create whole src structure. This is just in case this is tested out-
	// of-tree.
	require.NoError(t, os.MkdirAll(hierarchy, 0755))
	// Remove final component.
	require.NoError(t, os.Remove(hierarchy))
	// And replace with symlink to here.
	here, err := os.Getwd()
	require.NoError(t, err)
	require.NoError(t, os.Symlink(here, hierarchy))
	defer os.RemoveAll("tmp")

	// Update GOPATH.
	oldGopath := os.Getenv("GOPATH")
	require.NoError(t, os.Setenv("GOPATH", path.Join(here, "tmp")))
	defer os.Setenv("GOPATH", oldGopath)

	assert.NoError(t, checkMenderCompliance())

	// Now try an unexpected license.
	t.Run("Testing unexpected license", func(t *testing.T) {
		t.Log("Testing unexpected license")
		fd, err := os.Create("LICENSE.unexpected")
		require.NoError(t, err)
		fd.Close()
		defer os.RemoveAll("LICENSE.unexpected")

		assert.Error(t, checkMenderCompliance())
	})

	// Now try a Godep without license.
	t.Run("Testing Godep without a license", func(t *testing.T) {
		t.Log("Testing Godep without a license")
		require.NoError(t, os.MkdirAll("vendor/dummy-site.org/test-repo", 0755))
		fd, err := os.Create("vendor/dummy-site.org/test-repo/test.go")
		require.NoError(t, err)
		fd.Close()

		// LIFO order, we want to remove vendor/dummy-site.org first,
		// then potentially vendor, but not if it has other files in it.
		defer os.Remove("vendor")
		defer os.RemoveAll("vendor/dummy-site.org")

		assert.Error(t, checkMenderCompliance())
	})

	// Now try a Godep without license, but with README.md.
	t.Run("Testing Godep without license, but with README.md", func(t *testing.T) {
		t.Log("Testing Godep without license, but with README.md")
		require.NoError(t, os.MkdirAll("vendor/dummy-site.org/test-repo", 0755))
		fd, err := os.Create("vendor/dummy-site.org/test-repo/test.go")
		require.NoError(t, err)
		fd.Close()
		fd, err = os.Create("vendor/dummy-site.org/test-repo/README.md")
		require.NoError(t, err)
		fd.Close()

		// LIFO order, we want to remove vendor/dummy-site.org first,
		// then potentially vendor, but not if it has other files in it.
		defer os.Remove("vendor")
		defer os.RemoveAll("vendor/dummy-site.org")

		assert.Error(t, checkMenderCompliance())
	})

	// Now try a Godep with license in README.md, but no checksum.
	t.Run("Testing Godep with license, but no checksum", func(t *testing.T) {
		t.Log("Testing Godep with license, but no checksum")
		require.NoError(t, os.MkdirAll("tmp/vendor/dummy-site.org/test-repo", 0755))
		require.NoError(t, os.Chdir("tmp"))
		defer os.Chdir("..")
		fd, err := os.Create("vendor/dummy-site.org/test-repo/test.go")
		require.NoError(t, err)
		fd.Close()
		fd, err = os.Create("vendor/dummy-site.org/test-repo/README.md")
		require.NoError(t, err)
		fd.Close()

		SetLicenseFileForDependency("vendor/dummy-site.org/test-repo/README.md")
		defer resetKnownLicenses()

		defer os.Remove("tmp")

		assert.Error(t, checkMenderCompliance())
	})

	// Now try a Godep with license in README.md, with checksum.
	t.Run("Testing Godep with license in README.md, with checksum", func(t *testing.T) {
		t.Log("Testing Godep with license in README.md, with checksum")
		// We need a custom LIC_FILES_CHKSUM.sha256, so use a temp dir
		// for this one.
		require.NoError(t, os.MkdirAll("tmp/vendor/dummy-site.org/test-repo", 0755))
		require.NoError(t, os.Chdir("tmp"))
		defer os.Chdir("..")
		fd, err := os.Create("vendor/dummy-site.org/test-repo/test.go")
		require.NoError(t, err)
		fd.Close()
		fd, err = os.Create("vendor/dummy-site.org/test-repo/README.md")
		require.NoError(t, err)
		fd.Close()
		fd, err = os.Create("LICENSE")
		fmt.Fprintln(fd, "Copyright 2022 Northern.tech")
		require.NoError(t, err)
		fd.Close()

		fd, err = os.Create("LIC_FILES_CHKSUM.sha256")
		fmt.Fprintln(fd, "a7ca1fa6d48edbd8568ee8ee8f21379e8dbb07e97159240d23beffadd29f0956  LICENSE")
		fmt.Fprintln(fd, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  vendor/dummy-site.org/test-repo/README.md")
		require.NoError(t, err)
		fd.Close()

		SetLicenseFileForDependency("vendor/dummy-site.org/test-repo/README.md")
		defer resetKnownLicenses()

		defer os.Remove("tmp")

		assert.NoError(t, checkMenderCompliance())
	})

	// Now try an invalid GOPATH.
	t.Run("Testing with an invalid GOPATH", func(t *testing.T) {
		t.Log("Testing with an invalid GOPATH")
		require.NoError(t, os.Setenv("GOPATH", "/invalid"))

		assert.Error(t, checkMenderCompliance())
	})

	// Now try an unset GOPATH.
	t.Run("Try to unset the GOPATH", func(t *testing.T) {
		t.Log("Try to unset the GOPATH")
		require.NoError(t, os.Unsetenv("GOPATH"))

		assert.Error(t, checkMenderCompliance())
	})
}

func TestLicenses(t *testing.T) {
	assert.NoError(t, checkMenderCompliance())
}

func TestLicensesWithEnterprise(t *testing.T) {
	// Should produce the same result as nothing.
	SetFirstEnterpriseCommit("HEAD")
	defer SetFirstEnterpriseCommit("")
	assert.NoError(t, checkMenderCompliance())
}

func TestCommercialLicense(t *testing.T) {
	// Test a commercial license in a temporary folder.
	tmpdir, err := ioutil.TempDir("", "")
	require.NoError(t, err)
	defer os.RemoveAll(tmpdir)

	abspath, err := filepath.Abs("./test_commercial_license.sh")
	require.NoError(t, err)
	cmd := exec.Command(abspath, abspath)
	cmd.Dir = tmpdir
	err = cmd.Run()
	assert.NoError(t, err)
}

func TestMisformedLicenseChecksumLines(t *testing.T) {

	t.Log("Testing Godep with license in README.md, with checksum")
	// We need a custom LIC_FILES_CHKSUM.sha256, so use a temp dir
	// for this one.
	require.NoError(t, os.MkdirAll("tmp/vendor/dummy-site.org/test-repo", 0755))
	require.NoError(t, os.Chdir("tmp"))
	defer os.RemoveAll("tmp")
	defer os.Chdir("..")
	fd, err := os.Create("vendor/dummy-site.org/test-repo/test.go")
	require.NoError(t, err)
	fd.Close()
	fd, err = os.Create("vendor/dummy-site.org/test-repo/README.md")
	require.NoError(t, err)
	fd.Close()
	fd, err = os.Create("LICENSE")
	fmt.Fprintln(fd, "Copyright 2020 Northern.tech")
	require.NoError(t, err)
	fd.Close()

	fd, err = os.Create("LIC_FILES_CHKSUM.sha256")
	// This is one letter short of a full shasum line
	fmt.Fprintln(fd, "8c317e825d10807ce0a5e199300a68ea5efecce74c26e92cd3472c724b73d78  LICENSE")
	fmt.Fprintln(fd, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  vendor/dummy-site.org/test-repo/README.md")
	require.NoError(t, err)
	fd.Close()

	SetLicenseFileForDependency("vendor/dummy-site.org/test-repo/README.md")
	defer resetKnownLicenses()

	err = checkMenderCompliance()
	assert.Error(t, err, err.Error())
	assert.Contains(t, err.Error(), "Some line(s) in the LIC_FILE_CHKSUM.sha256 file are misformed")
}

type DirCmd struct {
	dir string
}

func (d *DirCmd) Command(cmd string, args ...string) *exec.Cmd {
	_cmd := exec.Command(cmd, args...)
	_cmd.Dir = d.dir
	return _cmd
}

func TestConventionalCommitMessages(t *testing.T) {

	os.Setenv("UNVERSIONED_REPOSITORY", "")
	os.Setenv("COMMIT_RANGE", "HEAD~1..HEAD")

	dir, err := ioutil.TempDir("/tmp", "test")
	require.NoError(t, err)
	t.Log(dir)
	defer os.RemoveAll(dir)
	cmds := [][]string{
		[]string{"commit", "--allow-empty", "-m", `feat(app): New feature added`},
		[]string{"commit", "--allow-empty", "-m", `fix(route): Fixed app routing`},
		[]string{"commit", "--allow-empty", "-m", `fix(route): Fixed app routing

BREAKING CHANGE: new route changes the API.
		`},
	}
	cmd := exec.Command("cp", "check_commits.sh", dir)
	_, err = cmd.CombinedOutput()
	dc := DirCmd{dir}
	cmd = dc.Command("git", "init", ".")
	_, err = cmd.CombinedOutput()
	cmd = dc.Command("git", "commit", "--allow-empty", "-m", "In the beginning there was darkness")
	_, err = cmd.CombinedOutput()
	cmd = dc.Command("git", "config", "user.name", "mendertester")
	output, err := cmd.CombinedOutput()
	require.NoError(t, err, string(output))
	cmd = dc.Command("git", "config", "user.email", "mendertester@mender.io")
	_, err = cmd.CombinedOutput()
	require.NoError(t, err)
	cmd = dc.Command("git", "commit", "--allow-empty", "-m", "In the beginning there was darkness")
	_, err = cmd.CombinedOutput()
	require.NoError(t, err)
	for _, args := range cmds {
		t.Log(args)
		cmd := dc.Command("git", args...)
		output, err := cmd.CombinedOutput()
		require.NoError(t, err, string(output))
		cmd = dc.Command("/bin/bash", "check_commits.sh", "--schema")
		output, err = cmd.CombinedOutput()
		assert.NoError(t, err, string(output))
	}

	cmds = [][]string{
		[]string{"commit", "--allow-empty", "-m", "Missing commit verb"},
	}
	for _, args := range cmds {
		cmd := dc.Command("git", args...)
		output, err := cmd.CombinedOutput()
		require.NoError(t, err, string(output))
		cmd = dc.Command("/bin/bash", "check_commits.sh", "--schema")
		output, err = cmd.CombinedOutput()
		assert.Error(t, err, string(output))
	}

}
