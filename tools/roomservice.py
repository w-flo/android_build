#!/usr/bin/env python
# Copyright (C) 2012-2013, The CyanogenMod Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from __future__ import print_function

import base64
import json
import netrc
import os
import re
import sys
try:
  # For python3
  import urllib.error
  import urllib.parse
  import urllib.request
except ImportError:
  # For python2
  import imp
  import urllib2
  import urlparse
  urllib = imp.new_module('urllib')
  urllib.error = urllib2
  urllib.parse = urlparse
  urllib.request = urllib2

from xml.etree import ElementTree

product = sys.argv[1];

phablet = {'branch': 'phablet-trusty',
           'fallback_branch': 'cm-10.1',
           'remote': 'phablet',
           'url_template': 'http://phablet.ubuntu.com/gitweb?p=CyanogenMod/%s.git;a=heads',
           }

if len(sys.argv) > 2:
    depsonly = sys.argv[2]
else:
    depsonly = None

try:
    device = product[product.index("_") + 1:]
except:
    device = product

if not depsonly:
    print("Device %s not found. Attempting to retrieve device "
          "repository from phablet.ubuntu.com and then from CyanogenMod "
          "Github (http://github.com/CyanogenMod)." % device)

repositories = []

try:
    authtuple = netrc.netrc().authenticators("api.github.com")

    if authtuple:
        githubauth = base64.encodestring('%s:%s' % (authtuple[0], authtuple[2])).replace('\n', '')
    else:
        githubauth = None
except:
    githubauth = None

def add_auth(githubreq):
    if githubauth:
        githubreq.add_header("Authorization","Basic %s" % githubauth)

page = 1
while not depsonly:
    githubreq = urllib.request.Request("https://api.github.com/users/CyanogenMod/repos?per_page=100&page=%d" % page)
    add_auth(githubreq)
    result = json.loads(urllib.request.urlopen(githubreq).read().decode())
    if len(result) == 0:
        break
    for res in result:
        repositories.append(res)
    page = page + 1

local_manifests = r'.repo/local_manifests'
if not os.path.exists(local_manifests): os.makedirs(local_manifests)

def exists_in_tree(lm, repository):
    for child in lm.getchildren():
        if child.attrib['name'].endswith(repository):
            return True
    return False

# in-place prettyprint formatter
def indent(elem, level=0):
    i = "\n" + level*"  "
    if len(elem):
        if not elem.text or not elem.text.strip():
            elem.text = i + "  "
        if not elem.tail or not elem.tail.strip():
            elem.tail = i
        for elem in elem:
            indent(elem, level+1)
        if not elem.tail or not elem.tail.strip():
            elem.tail = i
    else:
        if level and (not elem.tail or not elem.tail.strip()):
            elem.tail = i

def get_default_revision():
    m = ElementTree.parse(".repo/manifest.xml")
    d = m.findall('default')[0]
    r = d.get('revision')
    return r.split('/')[-1]

def get_from_manifest(devicename):
    try:
        lm = ElementTree.parse(".repo/local_manifests/roomservice.xml")
        lm = lm.getroot()
    except:
        lm = ElementTree.Element("manifest")

    for localpath in lm.findall("project"):
        if re.search("android_device_.*_%s$" % device, localpath.get("name")):
            return localpath.get("path")

    # Devices originally from AOSP are in the main manifest...
    try:
        mm = ElementTree.parse(".repo/manifest.xml")
        mm = mm.getroot()
    except:
        mm = ElementTree.Element("manifest")

    for localpath in mm.findall("project"):
        if re.search("android_device_.*_%s$" % device, localpath.get("name")):
            return localpath.get("path")

    return None

def is_in_manifest(projectname):
    try:
        lm = ElementTree.parse(".repo/local_manifests/roomservice.xml")
        lm = lm.getroot()
    except:
        lm = ElementTree.Element("manifest")

    for localpath in lm.findall("project"):
        if localpath.get("name") == projectname:
            return 1

    ## Search in main manifest, too
    try:
        lm = ElementTree.parse(".repo/manifest.xml")
        lm = lm.getroot()
    except:
        lm = ElementTree.Element("manifest")

    for localpath in lm.findall("project"):
        if localpath.get("name") == projectname:
            return 1

    return None

def add_to_manifest(repositories, fallback_branch = None):
    try:
        lm = ElementTree.parse(".repo/local_manifests/roomservice.xml")
        lm = lm.getroot()
    except:
        lm = ElementTree.Element("manifest")

    for repository in repositories:
        repo_name = repository['repository']
        repo_target = repository['target_path']
        if exists_in_tree(lm, repo_name):
            print('CyanogenMod/%s already exists' % (repo_name))
            continue

        print('Adding dependency: CyanogenMod/%s -> %s' % (repo_name, repo_target))
        project = ElementTree.Element("project", attrib = { "path": repo_target,
            "remote": "github", "name": "CyanogenMod/%s" % repo_name })

        if 'branch' in repository:
            project.set('revision',repository['branch'])
            if repository['branch'] == phablet['branch']:
                project.set('remote', phablet['remote'])
        elif fallback_branch:
            print("Using fallback branch %s for %s" % (fallback_branch, repo_name))
            project.set('revision', fallback_branch)
        else:
            print("Using default branch for %s" % repo_name)

        lm.append(project)

    indent(lm, 0)
    raw_xml = ElementTree.tostring(lm).decode()
    raw_xml = '<?xml version="1.0" encoding="UTF-8"?>\n' + raw_xml

    f = open('.repo/local_manifests/roomservice.xml', 'w')
    f.write(raw_xml)
    f.close()

def fetch_dependencies(repo_path, fallback_branch = None):
    print('Looking for dependencies')
    dependencies_path = repo_path + '/cm.dependencies'
    syncable_repos = []

    if os.path.exists(dependencies_path):
        dependencies_file = open(dependencies_path, 'r')
        dependencies = json.loads(dependencies_file.read())
        fetch_list = []

        for dependency in dependencies:
            if not is_in_manifest("CyanogenMod/%s" % dependency['repository']):
                if phablet_has_branch(dependency['repository'], phablet['branch']):
                    print('Found dependency (%s:%s) on phablet.ubuntu.com' %
                                    (dependency['repository'], phablet['branch']))
                    dependency['branch'] = phablet['branch']
                elif not fallback_branch:
                    fallback_branch = phablet['fallback_branch']
                fetch_list.append(dependency)
                syncable_repos.append(dependency['target_path'])

        dependencies_file.close()

        if len(fetch_list) > 0:
            print('Adding dependencies to manifest')
            add_to_manifest(fetch_list, fallback_branch)
    else:
        print('Dependencies file not found, bailing out.')

    if len(syncable_repos) > 0:
        print('Syncing dependencies')
        os.system('repo sync %s' % ' '.join(syncable_repos))

def phablet_has_branch(repository, revision):
    print("Searching for repository on phablet.ubuntu.com")
    phablet_url = phablet['url_template'] % repository
    try:
        request = urllib2.urlopen(phablet_url).read()
        heads_html = filter(lambda x: '<a class="list name"' in x,
                            request.split('\n'))
        heads = [ re.sub('<[^>]*>', '', i) for i in heads_html ]
        print("Found heads:")
        for head in heads:
            print(head)
        if revision in heads:
            return True
        else:
            return False
    except urllib2.HTTPError as e:
        if e.code == 404:
            print("Repository not found on phablet.ubuntu.com")
            print("This may likely be an unsupported build target")
            return False
        else:
            raise e

def has_branch(branches, revision):
    return revision in [branch['name'] for branch in branches]

if depsonly:
    repo_path = get_from_manifest(device)
    if repo_path:
        fetch_dependencies(repo_path)
    else:
        print("Trying dependencies-only mode on a non-existing device tree?")

    sys.exit()

else:
    for repository in repositories:
        repo_name = repository['name']
        if repo_name.startswith("android_device_") and repo_name.endswith("_" + device):
            print("Found repository: %s" % repository['name'])
            
            default_revision = get_default_revision()
            print("Default revision: %s" % default_revision)
            print("Checking branch info")

            manufacturer = repo_name.replace("android_device_", "").replace("_" + device, "")
            repo_path = "device/%s/%s" % (manufacturer, device)
            adding = {'repository':repo_name,'target_path':repo_path}
            
            fallback_branch = None
            if phablet_has_branch(repository['name'], default_revision):
                print('Found repository (%s:%s) on phablet.ubuntu.com' %
                                    (repository['name'], default_revision))
                adding['branch'] = default_revision
            else:
                githubreq = urllib.request.Request(repository['branches_url'].replace('{/branch}', ''))
                add_auth(githubreq)
                result = json.loads(urllib.request.urlopen(githubreq).read().decode())

                ## Try tags, too, since that's what releases use
                if not has_branch(result, default_revision):
                    githubreq = urllib.request.Request(repository['tags_url'].replace('{/tag}', ''))
                    add_auth(githubreq)
                    result.extend (json.loads(urllib.request.urlopen(githubreq).read().decode()))
            
                if not has_branch(result, default_revision):
                    found = False
                    if os.getenv('ROOMSERVICE_BRANCHES'):
                        fallbacks = list(filter(bool, os.getenv('ROOMSERVICE_BRANCHES').split(' ')))
                        for fallback in fallbacks:
                            if has_branch(result, fallback):
                                print("Using fallback branch: %s" % fallback)
                                fallback_branch = fallback
                                break

                    # Adding specifically for phablet
                    if has_branch(result, phablet['fallback_branch']):
                        print("Using %s as a fallback for %s" % \
                               (phablet['fallback_branch'], phablet['branch']))
                        found = True
                        fallback_branch = phablet['fallback_branch']

                    if not fallback_branch:
                        print("Default revision %s not found in %s. Bailing." % (default_revision, repo_name))
                        print("Branches found:")
                        for branch in [branch['name'] for branch in result]:
                            print(branch)
                        print("Use the ROOMSERVICE_BRANCHES environment variable to specify a list of fallback branches.")
                        sys.exit()

            add_to_manifest([adding], fallback_branch)

            print("Syncing repository to retrieve project.")
            os.system('repo sync %s' % repo_path)
            print("Repository synced!")

            fetch_dependencies(repo_path, fallback_branch)
            print("Done")
            sys.exit()

print("Repository for %s not found in the CyanogenMod Github repository list. If this is in error, you may need to manually add it to your local_manifests/roomservice.xml." % device)
