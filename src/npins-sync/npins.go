package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// splitURL splits "https://host/repo.git/branch" into url and branch.
func splitURL(source string) (string, string, error) {
	i := strings.LastIndex(source, "/")
	if i <= 0 || i == len(source)-1 {
		return "", "", fmt.Errorf("expected url/branch, got %q", source)
	}
	return source[:i], source[i+1:], nil
}

// run calls npins with the given arguments.
// Its output goes straight to our stdout/stderr.
func run(args ...string) error {
	cmd := exec.Command(npinsBin, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("npins %s: %w", strings.Join(args, " "), err)
	}
	return nil
}

// initPins creates a bare npins directory and adds nixpkgs.
func initPins(path, source string, channel bool) error {
	if err := run("-d", path, "init", "--bare"); err != nil {
		return err
	}
	if channel {
		return run("-d", path, "add", "channel", source)
	}
	url, branch, err := splitURL(source)
	if err != nil {
		return err
	}
	return run("-d", path, "add", "git", url, "--branch", branch)
}
