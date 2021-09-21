#!/usr/bin/env bash

# only on armv7l, which lacks wheels
if [[ "$TARGETPLATFORM" == "linux/arm/v7" ]]; then
    cd requirements/deterministic
    find -name "*.txt" -exec sed -i '/--hash/d' {} \;
    cd ../..
    cat >/etc/pip.conf <<EOF
[global]
extra-index-url=https://www.piwheels.org/simple
EOF
fi
