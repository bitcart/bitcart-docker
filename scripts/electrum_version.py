import requests
import base64
from subprocess import getstatusoutput as g

SITE_URL="https://electrum.org/version"

j=requests.get(SITE_URL).json()

version=j["version"]

tar_url="https://download.electrum.org/{version}/Electrum-{version}.tar.gz".format(version=version)
sig_url=tar_url+".asc"

with open("Electrum-{version}.tar.gz".format(version=version),"wb") as f:
    f.write(requests.get(tar_url).content)

with open("Electrum-{version}.tar.gz.asc".format(version=version),"wb") as f:
    f.write(requests.get(sig_url).content)

with open("ThomasV.asc","wb") as f:
    f.write(requests.get("https://raw.githubusercontent.com/spesmilo/electrum/master/pubkeys/ThomasV.asc").content)

g("gpg --import ThomasV.asc")
verify=g("gpg --verify Electrum-{version}.tar.gz.asc Electrum-{version}.tar.gz".format(version=version))[0]
if verify != 0:
    print('\033[31m'+ "Warning: Signature verify failed!" +'\033[0m')
else:
    g("pip3 install Electrum-{version}.tar.gz".format(version=version))
    print('\033[32m'+ "Success!" +'\033[0m')
