package main

import (
	"os"
	"syscall"
)

func redirectStderr(f *os.File) {
	syscall.Dup2(int(f.Fd()), 2)
}
