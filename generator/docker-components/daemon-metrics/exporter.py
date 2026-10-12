import asyncio
import json
import os
from urllib.parse import urlparse

import aiohttp
from aiohttp import BasicAuth, ClientSession, ClientTimeout
from prometheus_client import Gauge, start_http_server

SCRAPE_INTERVAL = int(os.getenv("METRICS_SCRAPE_INTERVAL", "30"))
METRICS_PORT = int(os.getenv("METRICS_PORT", "8000"))
BACKEND_URL = os.getenv("BACKEND_URL", "http://backend:8000")
BACKEND_TOKEN = os.getenv("BACKEND_TOKEN", "")
REQUEST_TIMEOUT = ClientTimeout(total=10)

GAUGES = {}


def get_gauge(name, description):
    if name not in GAUGES:
        GAUGES[name] = Gauge(f"daemon_{name}", description, ["daemon"])
    return GAUGES[name]


async def fetch_daemons(session):
    """Query backend /api/daemons to discover all enabled daemons."""
    headers = {"Authorization": f"Bearer {BACKEND_TOKEN}"} if BACKEND_TOKEN else {}
    async with session.get(f"{BACKEND_URL}/api/daemons", headers=headers, timeout=REQUEST_TIMEOUT) as resp:
        resp.raise_for_status()
        data = await resp.json()
    daemons = []
    for crypto, settings in data.items():
        creds = settings.get("credentials", {})
        rpc_url = creds.get("rpc_url", "")
        parsed = urlparse(rpc_url)
        host = parsed.hostname
        port = parsed.port
        if not host or not port:
            continue
        daemons.append(
            {
                "crypto": crypto,
                "host": host,
                "port": port,
                "user": creds.get("rpc_user", "electrum"),
                "password": creds.get("rpc_pass", "electrumz"),
            }
        )
    return daemons


async def fetch_getinfo(session, daemon):
    url = f"http://{daemon['host']}:{daemon['port']}/"
    payload = {"jsonrpc": "2.0", "id": 1, "method": "getinfo", "params": []}
    auth = BasicAuth(daemon["user"], daemon["password"])
    async with session.post(url, json=payload, auth=auth, timeout=REQUEST_TIMEOUT) as resp:
        data = await resp.json()
        return data.get("result", {})


def update_metrics(daemon_label, info):
    for key, value in info.items():
        if isinstance(value, (int, float)):
            get_gauge(key, f"getinfo field {key}").labels(daemon=daemon_label).set(value)
        elif isinstance(value, bool):
            get_gauge(key, f"getinfo field {key}").labels(daemon=daemon_label).set(int(value))


async def scrape_all():
    async with ClientSession() as session:
        try:
            daemons = await fetch_daemons(session)
        except Exception:
            return
        tasks = [fetch_getinfo(session, d) for d in daemons]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        for i, daemon in enumerate(daemons):
            result = results[i]
            if isinstance(result, Exception):
                get_gauge("reachable", "Whether daemon is reachable").labels(daemon=daemon["crypto"]).set(0)
                continue
            get_gauge("reachable", "Whether daemon is reachable").labels(daemon=daemon["crypto"]).set(1)
            update_metrics(daemon["crypto"], result)


async def main():
    start_http_server(METRICS_PORT)
    while True:
        await scrape_all()
        await asyncio.sleep(SCRAPE_INTERVAL)


if __name__ == "__main__":
    asyncio.run(main())
