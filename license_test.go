// Copyright 2019 Northern.tech AS
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

type mockT struct {
	*testing.T
}

func (self *mockT) Fatal(args ...interface{}) {
	// Need to get out of the calling function.
	panic(self)
}

func expectFailure(t *testing.T) {
	r := recover()
	if r == nil {
		t.Fatal("Expected failure, but did not encounter it")
	}
	switch r.(type) {
	case *mockT:
		break
	default:
		t.Fatal("Did not fail with correct type")
	}
}

func resetKnownLicenses() {
	known_license_files = []string{}
}

func TestMockLicenses(t *testing.T) {
	hierarchy := path.Join("tmp/src", packageLocation)

	// Create whole src structure. This is just in case this is tested out-
	// of-tree.
	require.True(t, os.MkdirAll(hierarchy, 0755) == nil)
	// Remove final component.
	require.True(t, os.Remove(hierarchy) == nil)
	// And replace with symlink to here.
	here, err := os.Getwd()
	require.True(t, err == nil)
	require.True(t, os.Symlink(here, hierarchy) == nil)
	defer os.RemoveAll("tmp")

	// Update GOPATH.
	oldGopath := os.Getenv("GOPATH")
	require.True(t, os.Setenv("GOPATH", path.Join(here, "tmp")) == nil)
	defer os.Setenv("GOPATH", oldGopath)

	CheckLicenses(t)

	// Now try an unexpected license.
	func() {
		fd, err := os.Create("LICENSE.unexpected")
		require.True(t, err == nil)
		fd.Close()
		defer os.RemoveAll("LICENSE.unexpected")
		defer expectFailure(t)

		var mock mockT = mockT{t}
		CheckLicenses(&mock)
	}()

	// Now try a Godep without license.
	func() {
		require.True(t, os.MkdirAll("vendor/dummy-site.org/test-repo", 0755) == nil)
		fd, err := os.Create("vendor/dummy-site.org/test-repo/test.go")
		require.True(t, err == nil)
		fd.Close()

		// LIFO order, we want to remove vendor/dummy-site.org first,
		// then potentially vendor, but not if it has other files in it.
		defer os.Remove("vendor")
		defer os.RemoveAll("vendor/dummy-site.org")

		defer expectFailure(t)

		var mock mockT = mockT{t}
		CheckLicenses(&mock)
	}()

	// Now try a Godep without license, but with README.md.
	func() {
		require.True(t, os.MkdirAll("vendor/dummy-site.org/test-repo", 0755) == nil)
		fd, err := os.Create("vendor/dummy-site.org/test-repo/test.go")
		require.True(t, err == nil)
		fd.Close()
		fd, err = os.Create("vendor/dummy-site.org/test-repo/README.md")
		require.True(t, err == nil)
		fd.Close()

		// LIFO order, we want to remove vendor/dummy-site.org first,
		// then potentially vendor, but not if it has other files in it.
		defer os.Remove("vendor")
		defer os.RemoveAll("vendor/dummy-site.org")

		defer expectFailure(t)

		var mock mockT = mockT{t}
		CheckLicenses(&mock)
	}()

	// Now try a Godep with license in README.md, but no checksum.
	func() {
		require.True(t, os.MkdirAll("tmp/vendor/dummy-site.org/test-repo", 0755) == nil)
		require.NoError(t, os.Chdir("tmp"))
		defer os.Chdir("..")
		fd, err := os.Create("vendor/dummy-site.org/test-repo/test.go")
		require.True(t, err == nil)
		fd.Close()
		fd, err = os.Create("vendor/dummy-site.org/test-repo/README.md")
		require.True(t, err == nil)
		fd.Close()

		SetLicenseFileForDependency("vendor/dummy-site.org/test-repo/README.md")
		defer resetKnownLicenses()

		defer os.Remove("tmp")

		defer expectFailure(t)

		var mock mockT = mockT{t}
		CheckLicenses(&mock)
	}()

	// Now try a Godep with license in README.md, with checksum.
	func() {
		// We need a custom LIC_FILES_CHKSUM.sha256, so use a temp dir
		// for this one.
		require.True(t, os.MkdirAll("tmp/vendor/dummy-site.org/test-repo", 0755) == nil)
		require.NoError(t, os.Chdir("tmp"))
		defer os.Chdir("..")
		fd, err := os.Create("vendor/dummy-site.org/test-repo/test.go")
		require.True(t, err == nil)
		fd.Close()
		fd, err = os.Create("vendor/dummy-site.org/test-repo/README.md")
		require.True(t, err == nil)
		fd.Close()
		fd, err = os.Create("LICENSE")
		fmt.Fprintln(fd, "Copyright 2019 Northern.tech")
		require.True(t, err == nil)
		fd.Close()

		fd, err = os.Create("LIC_FILES_CHKSUM.sha256")
		fmt.Fprintln(fd, "4412435dcd54a30de719b5d4d1cd6e7df785d3740fffe010f4a169d82fe95e7f  LICENSE")
		fmt.Fprintln(fd, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  vendor/dummy-site.org/test-repo/README.md")
		require.True(t, err == nil)
		fd.Close()

		SetLicenseFileForDependency("vendor/dummy-site.org/test-repo/README.md")
		defer resetKnownLicenses()

		defer os.Remove("tmp")

		CheckLicenses(t)
	}()

	// Now try an invalid GOPATH.
	func() {
		require.True(t, os.Setenv("GOPATH", "/invalid") == nil)
		defer expectFailure(t)

		var mock mockT = mockT{t}
		CheckLicenses(&mock)
	}()

	// Now try an unset GOPATH.
	func() {
		require.True(t, os.Unsetenv("GOPATH") == nil)
		defer expectFailure(t)

		var mock mockT = mockT{t}
		CheckLicenses(&mock)
	}()
}

func TestLicenses(t *testing.T) {
	CheckLicenses(t)
}

func TestLicensesWithEnterprise(t *testing.T) {
	// Should produce the same result as nothing.
	SetFirstEnterpriseCommit("HEAD")
	defer SetFirstEnterpriseCommit("")
	CheckLicenses(t)
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
