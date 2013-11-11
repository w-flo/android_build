#!/usr/bin/python3
import json
import urllib.request

host_uri = "https://system-image.ubuntu.com"
json_index_uri = "/devel/mako/index.json"

response = urllib.request.urlopen(host_uri + json_index_uri)

index_raw = response.read()

index = json.loads(index_raw.decode())

#Get first file (ubuntu-rootfs.tar.xz) from the last full (non-delta) version
tarball = [version['files'][0]['path'] for version in index['images'] if version['type'] == 'full'][-1]

print(host_uri + tarball)
