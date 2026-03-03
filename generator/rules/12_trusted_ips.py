import asyncio

import aiohttp

from generator.utils import env, modify_key

PRESET_URLS = {
    "cloudflare": [
        "https://www.cloudflare.com/ips-v4",
        "https://www.cloudflare.com/ips-v6",
    ],
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
    urls = PRESET_URLS.get(preset)
    if not urls:
        return

    async def fetch_all():
        return await asyncio.gather(*[fetch(url) for url in urls])

    results = asyncio.run(fetch_all())
    all_ips = [line.strip() for text in results for line in text.splitlines() if line.strip()]
    preset_ips = ",".join(all_ips)
    trusted_ips = env("REVERSEPROXY_TRUSTED_IPS", prefix="")
    combined = f"{preset_ips},{trusted_ips}" if trusted_ips else preset_ips
    with modify_key(services, "nginx-gen", "environment") as environment:
        environment["TRUSTED_IPS"] = combined
