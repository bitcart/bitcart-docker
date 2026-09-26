package main

import (
	"os"
	"syscall"
)

func redirectStderr(f *os.File) {
	syscall.Dup3(int(f.Fd()), 2, 0)
}
