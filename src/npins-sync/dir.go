// npins-sync/dir
// Initialise or update an npins directory.
package main

import (
	"os"
	"path/filepath"
)

// isEmpty reports whether a directory has no entries.
func isEmpty(path string) (bool, error) {
	entries, err := os.ReadDir(path)
	if err != nil {
		return false, err
	}
	return len(entries) == 0, nil
}

// clearDir removes everything inside a directory, keeping the directory.
func clearDir(path string) error {
	entries, err := os.ReadDir(path)
	if err != nil {
		return err
	}
	for _, e := range entries {
		if err := os.RemoveAll(filepath.Join(path, e.Name())); err != nil {
			return err
		}
	}
	return nil
}
