#!/usr/bin/python3
#
# get-tarball-url -- compute tarball url from system-image.ubuntu.com
#
# Copyright (C) 2013, Canonical Ltd.
#
# Based on the code in phablet-tools
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# See file /usr/share/common-licenses/GPL for more details.
#
# Author: Dmitrijs Ledkovs <dmitrijs.ledkovs@canonical.com>

import json
import sys
import urllib.request

host_uri = "https://system-image.ubuntu.com"
json_index_uri = "/devel-proposed/mako/index.json"

response = urllib.request.urlopen(host_uri + json_index_uri)

index_raw = response.read()

index = json.loads(index_raw.decode())

#Get first file (ubuntu-rootfs.tar.xz) from the last full (non-delta) version
latest_version = [version for version in index['images'] if version['type'] == 'full'][-1]
tarball = latest_version['files'][0]['path']
version = latest_version['version']

print("INFO: Using system-image tarball version %s" % version, file=sys.stderr)
print(host_uri + tarball)
