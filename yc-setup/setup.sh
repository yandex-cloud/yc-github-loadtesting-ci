#!/usr/bin/env bash

sudo DEBIAN_FRONTEND=noninteractive apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y curl jq

sudo curl -f -s -LO https://storage.yandexcloud.net/yandexcloud-yc/install.sh
sudo bash install.sh -i /usr/local/yandex-cloud -n
sudo ln -sf /usr/local/yandex-cloud/bin/yc /usr/local/bin/yc

if [[ -n "$YC_LT_AUTHORIZED_KEY_JSON_BASE64" ]]; then
    cat >key.pem < <(echo "$YC_LT_AUTHORIZED_KEY_JSON_BASE64")
    base64 -d >key.json <key.pem
elif [[ -n "$YC_LT_AUTHORIZED_KEY_JSON" ]]; then
    cat >key.raw < <(echo "$YC_LT_AUTHORIZED_KEY_JSON")
    cat >key.json <key.raw
fi

if [[ ! -f key.json ]]; then
    echo "No valid authorized key. Either YC_LT_AUTHORIZED_KEY_JSON_BASE64 (recommended) or YC_LT_AUTHORIZED_KEY_JSON must be set."
    exit 1
fi

yc config profile create sa-profile && yc config profile activate sa-profile
yc config set service-account-key ./key.json
yc config set format json
yc config set folder-id "$YC_LT_FOLDER_ID"
