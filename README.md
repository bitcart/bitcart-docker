# BitcartCC Docker Deployment

[![CircleCI](https://circleci.com/gh/bitcartcc/bitcart-docker.svg?style=svg)](https://circleci.com/gh/bitcartcc/bitcart-docker)
![Codecov](https://img.shields.io/codecov/c/github/bitcartcc/bitcart-docker?style=flat-square)

## Using provided scripts (easy)

To install BitcartCC, if you're on linux system(these scripts for windows will be added soon),
to download, set up, and run your BitcartCC instance, it is a matter of few commands:

```bash
sudo su -
git clone https://github.com/bitcartcc/bitcart-docker
cd bitcart-docker
# set needed environment variables, see below
./setup.sh
```

By default it will set up a systemd/upstart service to ensure your instance is running 24/7.
To configure your installation you can set different environment variables.

There are two types of environment variables: generator and app.
To understand how generator works, see [Architecture](#architecture).

Here is an example of the setup you will use in 90% cases. Replace `yourdomain.tld` with your actual domain (for bitcartcc demo, it was `bitcartcc.com`):

```bash
sudo su -
git clone https://github.com/bitcartcc/bitcart-docker
cd bitcart-docker
export BITCART_HOST=yourdomain.tld
./setup.sh
```

This setup utilizes the [one domain mode](https://docs.bitcartcc.com/guides/one-domain-mode). We recommend you to read about that.

**Important: for everything to work, you will need to first set up DNS A records for** `BITCART_HOST`**,** `BITCART_ADMIN_HOST` **(if set) and** `BITCART_STORE_HOST` **(if set) to point to the server where you are deploying BitcartCC.**

![DNS A records for bitcartcc demo](https://raw.githubusercontent.com/bitcartcc/bitcart-docs/master/.gitbook/assets/namecheap_dns_records.png)

_**Tip:**_ All the `_HOST` environment variables determine on which host (domain, without protocol) to run a service. All the `_URL` environment variables are to specify the URL (with protocol, http:// or https://) of the BitcartCC Merchants API to use.

_**Tip:**_ if you want to try out BitcartCC locally on your PC without a server, you can either enable [Tor support](https://docs.bitcartcc.com/guides/tor) or use local deployment mode.

For that, replace `yourdomain.tld` with `bitcart.local` (or any domain ending in `.local`), and it will modify `/etc/hosts` for you, for it to work like a regular domain. If using local deployment mode, of course your instance will only be accessible from your PC.

If not using the [one domain mode](https://docs.bitcartcc.com/guides/one-domain-mode), then you would probably run:

```bash
sudo su -
git clone https://github.com/bitcartcc/bitcart-docker
cd bitcart-docker
export BITCART_HOST=api.yourdomain.tld
export BITCART_ADMIN_HOST=admin.yourdomain.tld
export BITCART_STORE_HOST=store.yourdomain.tld
export BITCART_ADMIN_API_URL=https://api.yourdomain.tld
export BITCART_STORE_API_URL=https://api.yourdomain.tld
./setup.sh
```

Why was it done like so? It's because it is possible to run Merchants API on one server, and everything else on different servers.

But in most cases, you can basically do:

```bash
# if https (BITCART_REVERSEPROXY=nginx-https, default)
export BITCART_ADMIN_API_URL=https://$BITCART_HOST
export BITCART_STORE_API_URL=https://$BITCART_HOST
# if http (BITCART_REVERSEPROXY=nginx, local deployments, other)
export BITCART_ADMIN_API_URL=http://$BITCART_HOST
export BITCART_STORE_API_URL=http://$BITCART_HOST
```

## Configuration

Configuration settings are set like so:

    export VARIABLE_NAME=value

Here is a complete list of configuration settings:

| Name                          | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | Default     | Type      |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- | --------- |
| BITCART_HOST                  | Host where to run BitcartCC Merchants API. Is used when merchants API (backend component) is enabled.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | :x:         | App       |
| BITCART_STORE_HOST            | Host where to run BitcartCC Ready Store. Is used when store component is enabled.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | :x:         | App       |
| BITCART_ADMIN_HOST            | Host where to run BitcartCC Admin Panel. Is used when admin component is enabled.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | :x:         | App       |
| BITCART_STORE_API_URL         | URL of BitcartCC Merchants API instance. It can be your instance hosted together with store or a completely separate instance. In case of default setup (store+admin+API at once), you need to set it to https://$BITCART_HOST or (http if nginx-https component is not enabled).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | :x:         | App       |
| BITCART_ADMIN_API_URL         | Same as BITCART_STORE_API_URL, but for configuring your admin panel.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | :x:         | App       |
| BITCART_LETSENCRYPT_EMAIL     | Email used for notifying you about your https certificates. Usually no action is needed to renew your certificates, but otherwise you'll get an email. Is used when nginx-https component is enabled.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | :x:         | App       |
| COINNAME_NETWORK              | Used for configuring network of COINNAME daemon. Daemon can be run in only one network at once. Possible values are mainnet, testnet, and sometimes regtest and simnet. This setting affects only daemon of COINNAME, you need to set this value for each coin daemon you want to customize.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | mainnet     | App       |
| COINNAME_LIGHTNING            | Used for enabling/disabling lightning support of COINNAME daemon. Some coins might not support lightning, in this case this setting does nothing. Possible values are true, false or not set. This setting affects only daemon of COINNAME, you need to set this value for each coin daemon you want to customize.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | false       | App       |
| BITCART_INSTALL               | Used for enabling different ready installation presets, instead of including certain components manually. Currently possible values are: all (enable backend and frontend component groups), backend (backend group only), frontend (frontend group only), none (no preset enabled, by default only enabled component in that case is btc daemon. It is used in custom setups where merchants features aren't needed, and only daemons are needed to be managed by docker stack). Component groups include a few components to ensure all pieces work. Backend group currently includes postgres, redis and merchants API. If only this group is enabled it can be used as API for deployments on a different server for example. Frontend group includes admin and store. They either use built-in merchants API or a custom hosted one. | all         | Generator |
| BITCART_CRYPTOS               | Used for configuring enabled crypto daemons. It is a comma-separated list of coin names, where each name is a coin code (for example btc, ltc). Each daemon component is enabled when it's respective coin code is in the list.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | btc         | Generator |
| BITCART_REVERSEPROXY          | Used for choosing reverse proxy in current docker-compose stack. Possible variants are: nginx-https(nginx+let's encrypt automatic ssl certificates), nginx(just nginx reverseproxy), none(no reverse proxy). Note that all HOST settings are applied only when nginx or nginx-https is enabled. When reverse proxy is none, few services expose their ports to the outside internet. By default they don't. List of those services: backend, admin, store and different coins if BITCART_COINAME_EXPOSE is true.                                                                                                                                                                                                                                                                                                                          | nginx-https | Generator |
| BITCART_ADDITIONAL_COMPONENTS | A space separated list of additional components to add to docker-compose stack. Enable custom integrations or your own developed components, making your app fit into one container stack. (allows communication between containers, using same db, redis, etc.)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | :x:         | Generator |
| BITCART_COINNAME_EXPOSE       | Used only when no reverse proxy is enabled. By default daemons aren't exposed to outside internet and are accessible only from inside container network (from other containers). Note that exposing daemon port to outside is a security risk, as potentially your daemon might be using default credentials that can be viewed from source code. Only do that if you know what you're doing! Merchants API exists for many reasons, and one of those is to protect daemons from direct access.                                                                                                                                                                                                                                                                                                                                           | :x:         | Generator |
| BITCART_COMPONENT_PORT        | Used when no reverse proxy is enabled. By default certain services are exposed to outside by their internal ports (3000 for store, 4000 for admin, 8000 for merchants API, 500X for daemons). Use that to override external container port. Here component is the internal component name. It can be found in generator/docker-components directory. For example for store it is store, for admin it is admin, for merchants API-backend, for bitcoin daemon-bitcoin. When unset, default port is used.                                                                                                                                                                                                                                                                                                                                   | :x:         | Generator |
| TOR_RELAY_NICKNAME            | If tor relay is activated, the relay nickname                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | :x:         | Extension |
| TOR_RELAY_EMAIL               | If tor relay is activated, the email for Tor to contact you regarding your relay                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | :x:         | Extension |

## Live demo

We have live demo available at:

- [https://admin.bitcartcc.com](https://admin.bitcartcc.com/) BitcartCC Admin Panel
- [https://store.bitcartcc.com](https://store.bitcartcc.com/) BitcartCC Ready Store POS
- [https://api.bitcartcc.com](https://api.bitcartcc.com/) BitcartCC Merchants API

Note that it isn't designed for your production use, it is for testing and learning.

## Guide: how demo was set up

Basically via deployment steps above (:

Here are the commands used on our demo, as of Februrary 2021, BitcartCC Version 0.2.2.0:

```bash
sudo su -
git clone https://github.com/bitcartcc/bitcart-docker
cd bitcart-docker
# host settings
export BITCART_HOST=api.bitcartcc.com
export BITCART_ADMIN_HOST=admin.bitcartcc.com
export BITCART_STORE_HOST=store.bitcartcc.com
export BITCART_ADMIN_API_URL=https://api.bitcartcc.com
export BITCART_STORE_API_URL=https://api.bitcartcc.com
# reverse proxy settings, we use none because we configure nginx manually
export BITCART_REVERSEPROXY=none
# cryptocurrency settings
# we enable all currencies we support on the demo to test that they work
export BITCART_CRYPTOS=btc,bch,ltc,bsty,xrg,eth
# lightning network for supported coins
export BTC_LIGHTNING=true
export LTC_LIGHTNING=true
export BSTY_LIGHTNING=true
# tor support
export BITCART_ADDITIONAL_COMPONENTS=tor
./setup.sh
```

## Development builds

Currently the testing of individual pieces of BitcartCC is done via local development installation, see [Manual Deployment](https://docs.bitcartcc.com/deployment/manual) about how it is done.

When doing some changes in generator, it is usually tested via local python installation, like so:

```bash
cd generator
pip3 install oyaml
python3 main.py
cd ..
cat compose/generated.yml # see the generated output
```

If it is needed to test generator in docker, then run those commands:

```bash
export BITCARTGEN_DOCKER_IMAGE=bitcartcc/docker-compose-generator:local
./build.sh # now uses local image
```

## Architecture

To provide a variety of deployment methods, to fit in every possible use case, we use a custom generator system.
All the services are run by docker-compose.
It makes it possible for containers to communicate between each other without exposing sensitive APIs to outside network.

Usually, to launch docker-compose cluster a docker-compose.yml is required.

In our case it is not present, as it is generated dynamically.

When running generator manually, or as a part of easy deployment, generator is called (either dockerized or via local python).

It runs a simple python script, it's purpose is to generated docker compose configuration file based on environment variables set.

See [Configuration](#configuration) section above about how different configuration settings affect the choice of components.

After getting a list of components to load, generator tries to load each of the components.
It loads components from `generator/docker-components` directory. Each component is a piece of complete docker-compose.yml file,
having service it provides, and any additional changes to other components.

If no service with that name is found, it is just skipped.

Each component might have services (containers), networks and volumes (for storing persistent data).

All that data is collected from each component, and then all the services list is merged (it is done to make configuring one component from another one possible).

After merging data into complete setup, generator applies a set of rules on them.
Rules are python scripts, which can dynamically change some settings of components based on configuration settings or enabled components.

Rules are loaded from `generator/rules` directory. Each rule is a python file.
Each python file (.py) must define rule function, accepting a single parameter - services.

If such function exists, it will be called with current services dictionary.
Rules can modify that based on different settings.
There are a few default settings bundled with BitcartCC (for example, to expose ports to outside when no reverse proxy is enabled).
You can create your own rules to add completely custom settings for your deployment.
Your BitcartCC deployment is not only BitcartCC itself, but also a powerful and highly customizable ocker-compose stack generator.

After applying rules, the resulting data is written to compose/generated.yml file, which is final docker-compose.yml file used by startup scripts.
