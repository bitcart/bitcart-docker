# Upgrade helpers

## Automatic upgrades

Scripts named `YYYYMMDD-description.sh` run automatically, once per deployment, at the end of `update.sh` and `setup.sh`, after the stack has started. They run in name order, and the applied ones are recorded in `BITCART_UPGRADES` in `.deploy`. A script that fails stops the rest and is retried by the next update. A new deployment records all of them as applied without running them.

To add one, name it by the date it is written, and make it:

- exit 0 once the upgrade is done or there is nothing to do, and non-zero to be retried later;
- start with `cd "$(dirname "${BASH_SOURCE[0]}")/../.."`, then source `helpers.sh` (and `host-agent/helpers.sh` for host agent functions) and run `load_env`.

Current list:

- `20260924-host-agent.sh`: removes the unrestricted root SSH key that containers used before the host agent, once the new worker reaches the agent

## Manual upgrades

These older helpers in `legacy/` are one-time fixes for specific problems, and never run automatically. Run them only if their description applies, with your docker deployment running:

`contrib/upgrades/legacy/upgrade-to-version.sh`

- `upgrade-to-0500.sh`, helps to upgrade to Bitcart 0.5.0.0, run this in case you get a migration error (invalid foreign key constraints names). It might be required for older Bitcart deployments, requires a running database container
- `upgrade-to-0600.sh`, helps to upgrade to Bitcart 0.6.0.0, run this if you need to migrate your logs and images
- `upgrade-to-0610.sh`, helps to change postgresql config to allow password-less login
- `upgrade-to-0680.sh`, helps to fix permissions on tor hidden services volumes
- `upgrade-to-0800.sh`, helps to rename the BitcartCC profile file and systemd service to Bitcart
