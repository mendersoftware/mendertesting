// Copyright 2016 Mender Software AS
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

import "os"
import "path"
import "testing"

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

func TestLicenses(t *testing.T) {
	hierarchy := path.Join("tmp/src", packageLocation)

	// Create whole src structure. This is just in case this is tested out-
	// of-tree.
	AssertTrue(t, os.MkdirAll(hierarchy, 0755) == nil)
	// Remove final component.
	AssertTrue(t, os.Remove(hierarchy) == nil)
	// And replace with symlink to here.
	here, err := os.Getwd()
	AssertTrue(t, err == nil)
	AssertTrue(t, os.Symlink(here, hierarchy) == nil)
	defer os.RemoveAll("tmp")

	// Update GOPATH.
	oldGopath := os.Getenv("GOPATH")
	AssertTrue(t, os.Setenv("GOPATH", path.Join(here, "tmp")) == nil)
	defer os.Setenv("GOPATH", oldGopath)

	CheckLicenses(t)

	// Now try an unexpected license.
	func() {
		fd, err := os.Create("LICENSE.unexpected")
		AssertTrue(t, err == nil)
		fd.Close()
		defer os.RemoveAll("LICENSE.unexpected")
		defer expectFailure(t)

		var mock mockT = mockT{t}
		CheckLicenses(&mock)
	}()

	// Now try a Godep without license.
	func() {
		AssertTrue(t, os.MkdirAll("vendor/dummy-site.org/test-repo", 0755) == nil)
		fd, err := os.Create("vendor/dummy-site.org/test-repo/test.go")
		AssertTrue(t, err == nil)
		fd.Close()

		// LIFO order, we want to remove vendor/dummy-site.org first,
		// then potentially vendor, but not if it has other files in it.
		defer os.Remove("vendor")
		defer os.RemoveAll("vendor/dummy-site.org")

		defer expectFailure(t)

		var mock mockT = mockT{t}
		CheckLicenses(&mock)
	}()

	// Now try an invalid GOPATH.
	func() {
		AssertTrue(t, os.Setenv("GOPATH", "/invalid") == nil)
		defer expectFailure(t)

		var mock mockT = mockT{t}
		CheckLicenses(&mock)
	}()

	// Now try an unset GOPATH.
	func() {
		AssertTrue(t, os.Unsetenv("GOPATH") == nil)
		defer expectFailure(t)

		var mock mockT = mockT{t}
		CheckLicenses(&mock)
	}()
}
