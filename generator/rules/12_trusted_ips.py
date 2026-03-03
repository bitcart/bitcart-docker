import asyncio

import aiohttp

from generator.utils import env, modify_key

PRESET_URLS = {
    "cloudflare": "https://www.cloudflare.com/ips-v4",
}


async def fetch(url):  # pragma: no cover
    async with aiohttp.ClientSession() as session, session.get(url) as response:
        return await response.text()


def rule(services, settings):
    preset = env("REVERSEPROXY_TRUSTED_IPS_PRESET", prefix="")
    if not preset:
        return
    if not services.get("nginx-gen"):  # pragma: no cover
        return
    url = PRESET_URLS.get(preset)
    if not url:
        return
    fetched = asyncio.run(fetch(url)).strip()
    preset_ips = ",".join(line.strip() for line in fetched.splitlines() if line.strip())
    trusted_ips = env("REVERSEPROXY_TRUSTED_IPS", prefix="")
    combined = f"{preset_ips},{trusted_ips}" if trusted_ips else preset_ips
    with modify_key(services, "nginx-gen", "environment") as environment:
        environment["TRUSTED_IPS"] = combined
