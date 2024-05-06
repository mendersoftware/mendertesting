// Copyright 2024 Northern.tech AS
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

	"errors"
	"strings"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const packageLocation string = "github.com/mendersoftware/mendertesting"

var known_license_files []string = []string{}

// Specify a license file for a dependency explicitly, avoiding the check for
// common license file names.
func SetLicenseFileForDependency(license_file string) {
	known_license_files = append(known_license_files, "--add-license="+license_file)
}

var firstEnterpriseCommit = ""

// This should be set to the oldest commit that is not part of Open Source, only
// part of Enterprise, if any. IOW it should be the very first commit after the
// fork point, on the Enterprise branch.
func SetFirstEnterpriseCommit(sha string) {
	firstEnterpriseCommit = sha
}

func CheckMenderCompliance(t *testing.T) {
	t.Run("Checking Mender compliance", func(t *testing.T) {
		err := checkMenderCompliance()
		assert.NoError(t, err)
	})
}

type MenderComplianceError struct {
	Output string
	Err    error
}

func (m *MenderComplianceError) Error() string {
	return fmt.Sprintf("MenderCompliance failed with error: %s\nOutput: %s\n", m.Err, m.Output)
}

func checkMenderCompliance() error {
	pathToTool, err := locatePackage()
	if err != nil {
		return err
	}

	args := []string{path.Join(pathToTool, "check_license_source_files.sh")}
	if firstEnterpriseCommit != "" {
		args = append(args, "--ent-start-commit", firstEnterpriseCommit)
	}
	cmd := exec.Command("bash", args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return &MenderComplianceError{
			Err:    err,
			Output: string(output),
		}
	}

	args = []string{path.Join(pathToTool, "check_commits.sh")}
	cmd = exec.Command("bash", args...)
	output, err = cmd.CombinedOutput()
	if err != nil {
		return &MenderComplianceError{
			Err:    err,
			Output: string(output),
		}
	}

	args = []string{path.Join(pathToTool, "check_license.sh")}
	args = append(args, known_license_files...)
	cmd = exec.Command("bash", args...)
	output, err = cmd.CombinedOutput()
	if err != nil {
		return &MenderComplianceError{
			Err:    err,
			Output: string(output),
		}
	}
	return nil
}

func locatePackage() (string, error) {
	finalpath := path.Join("vendor", packageLocation)
	_, err := os.Stat(finalpath)
	if err == nil {
		return finalpath, nil
	}

	gopath := os.Getenv("GOPATH")
	if gopath == "" {
		return "", errors.New("Cannot check for licenses if " +
			"mendertesting is not vendored and GOPATH is unset.")
	}

	paths := strings.Split(gopath, ":")
	for i := 0; i < len(paths); i++ {
		finalpath = path.Join(paths[i], "src", packageLocation)
		_, err := os.Stat(finalpath)
		if err == nil {
			return finalpath, nil
		}
	}

	return "", fmt.Errorf("Package '%s' could not be located anywhere in GOPATH (%s)",
		packageLocation, gopath)
}

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
		fmt.Fprintln(fd, "Copyright 2024 Northern.tech")
		require.NoError(t, err)
		fd.Close()

		fd, err = os.Create("LIC_FILES_CHKSUM.sha256")
		fmt.Fprintln(fd, "44144c96fba50432e0ac319fda306128f44ea9212532ea1f7cd9b72f0642d9f2  LICENSE")
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
	// The code below sets the Enterprise commit to HEAD, and then expects
	// the license test to produce no errors. This is logical, because all
	// code was already Open Source, except in HEAD. However, it doesn't
	// work if we have added a new file in HEAD. Therefore, produce a
	// throwaway commit which is one step beyond HEAD, and use that as the
	// Enterprise commit instead.
	cmd := exec.Command("bash", "-c", "git commit-tree -p HEAD -m test `git cat-file commit HEAD | grep '^tree ' | awk '{print $2}'`")
	output, err := cmd.Output()
	require.NoError(t, err)

	// Should produce the same result as nothing.
	SetFirstEnterpriseCommit(string(output))
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
	output, err := cmd.CombinedOutput()
	assert.NoError(t, err, string(output))
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
