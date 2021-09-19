# Upgrade helpers

This directory contains a list of files to help upgrade to various BitcartCC versions.

To apply any fix (note, scripts are one-time only in most cases), just run:

`contrib/upgrades/upgrade-to-version.sh`

Your docker deployment should be running.

Current list:

- `upgrade-to-5000.sh`, helps to upgrade to BitcartCC 0.5.0.0, run this in case you get a migration error (invalid foreign key constraints names). It might be required for older BitcartCC deployments, requires a running database container
- `upgrade-to-0600.sh`, helps to upgrade to BitcartCC 0.6.0.0, run this if you need to migrate your logs and images
