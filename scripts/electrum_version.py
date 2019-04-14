import os
from subprocess import getstatusoutput as g

import requests

SITE_URL = "https://electrum.org/version"
name_file = []

j = requests.get(SITE_URL).json()

version = j["version"]

tar_url = "https://download.electrum.org/{version}/Electrum-{version}.tar.gz".format(version=version)
sig_url = tar_url + ".asc"

with open("Electrum-{version}.tar.gz".format(version=version), "wb") as f:
    f.write(requests.get(tar_url).content)
    name_file.append(f.name)

with open("Electrum-{version}.tar.gz.asc".format(version=version), "wb") as f:
    f.write(requests.get(sig_url).content)
    name_file.append(f.name)

with open("ThomasV.asc", "wb") as f:
    f.write(requests.get("https://raw.githubusercontent.com/spesmilo/electrum/master/pubkeys/ThomasV.asc").content)
    name_file.append(f.name)

print("Verifying signature...")

g("gpg --import ThomasV.asc")
verify = g("gpg --verify Electrum-{version}.tar.gz.asc Electrum-{version}.tar.gz".format(version=version))[0]

if verify != 0:
    print('\033[31m' + "Warning: Signature verify failed!" + '\033[0m')
else:
    print("Installing electrum, it might take a while...")
    g("pip3 install Electrum-{version}.tar.gz".format(version=version))
    print('\033[32m' + "Success!" + '\033[0m')

for name in name_file:
    try:
        os.remove(name)
    except Exception:
        pass
print("test")
