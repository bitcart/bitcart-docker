//go:build race

package main

func init() { agentBuildFlags = append(agentBuildFlags, "-race") }
