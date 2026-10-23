// npins-sync
// Initialise or update an npins directory.
package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
)

// npinsBin can be overridden at build time:
//
//	-ldflags "-X main.npinsBin=/nix/store/.../bin/npins"
var npinsBin = "npins"

func usage() {
	fmt.Fprintf(os.Stderr,
		"Usage: %s [-f] -d directory (-u url/branch | -c channel)\n",
		filepath.Base(os.Args[0]))
	os.Exit(2)
}

func main() {

	// make all parameters
	var (
		force   bool
		path    string
		url     string
		channel string
	)
	flag.BoolVar(&force, "f", false, "clear and reinitialise if update fails")
	flag.StringVar(&path, "d", "", "npins directory")
	flag.StringVar(&url, "u", "", "git url/branch")
	flag.StringVar(&channel, "c", "", "channel name")
	flag.Usage = usage
	flag.Parse()

	if path == "" || (url == "") == (channel == "") {
		// handle u and c compatibility
		if (url == "") == (channel == "") {
			fmt.Fprintln(os.Stderr, "Error: exactly one of -u or -c is required")
		}
		usage()
	}

	source, isChannel := url, false
	if channel != "" {
		source, isChannel = channel, true
	}

	empty, err := isEmpty(path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "directory %s cannot be read: %v\n", path, err)
		os.Exit(1)
	}
	if empty {
		if err := initPins(path, source, isChannel); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	}

	if err := run("-d", path, "update"); err != nil {
		fmt.Fprintln(os.Stderr, err)
		if !force {
			fmt.Fprintf(os.Stderr,
				"npins update failed, check content of %s, or rerun with -f\n", path)
			os.Exit(1)
		}
		if err := clearDir(path); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		if err := initPins(path, source, isChannel); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	}
}
