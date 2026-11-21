import asyncio

import aiohttp

from generator.utils import env, modify_key

PRESET_URLS = {
    "cloudflare": [
        "https://www.cloudflare.com/ips-v4",
        "https://www.cloudflare.com/ips-v6",
    ],
}

PRESET_IPS = {
    "docker": ["172.16.0.0/12"],
}

PRESET_HEADERS = {
    "cloudflare": ["X-Forwarded-Proto"],
    "docker": ["X-Forwarded-Proto"],
}


async def fetch(url):  # pragma: no cover
    async with aiohttp.ClientSession() as session, session.get(url) as response:
        return await response.text()


def load_preset_ips(preset):
    if preset in PRESET_IPS:
        return PRESET_IPS[preset]
    urls = PRESET_URLS.get(preset)
    if not urls:
        return None

    async def fetch_all():
        return await asyncio.gather(*[fetch(url) for url in urls])

    results = asyncio.run(fetch_all())
    return [line.strip() for text in results for line in text.splitlines() if line.strip()]


def rule(services, settings):
    preset = env("REVERSEPROXY_TRUSTED_IPS_PRESET", prefix="")
    if not preset:
        return
    if not services.get("nginx-gen"):  # pragma: no cover
        return
    all_ips = load_preset_ips(preset)
    if all_ips is None:
        return
    preset_ips = ",".join(all_ips)
    trusted_ips = env("REVERSEPROXY_TRUSTED_IPS", prefix="")
    combined = f"{preset_ips},{trusted_ips}" if trusted_ips else preset_ips
    preset_headers = PRESET_HEADERS.get(preset, [])
    trusted_headers = env("REVERSEPROXY_TRUSTED_HEADERS", prefix="")
    user_headers = [h.strip() for h in trusted_headers.split(",") if h.strip()] if trusted_headers else []
    combined_headers = ",".join(dict.fromkeys(preset_headers + user_headers))
    with modify_key(services, "nginx-gen", "environment") as environment:
        environment["TRUSTED_IPS"] = combined
        if combined_headers:
            environment["TRUSTED_HEADERS"] = combined_headers
