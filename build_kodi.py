#!/usr/bin/env python3
from datetime import datetime, timezone
import locale
import logging
import os
import subprocess
import sys


THISDIR = os.path.dirname(__file__)
logging.basicConfig(
    level=logging.INFO, 
    format="[%(asctime)s] %(levelname)8s: %(message)s"
)

def fail(msg):
    logging.error(msg)
    sys.exit(1)

try:
    OLD_VERSION = sys.argv[1]
except:
    fail(f"Usage: {sys.argv[0]} <old version string> [our debian rev override]")

logging.info("Retrieving source...")
subprocess.check_call(f"apt source kodi={OLD_VERSION}".split())
rest, *_epoch = reversed(OLD_VERSION.split(":", 1))
upstream_rev, debian_rev = rest.rsplit("-", 1)
our_debian_rev = (sys.argv[2:] or [debian_rev])[0]
new_version = f"10:{upstream_rev}-{our_debian_rev}"
logging.info("Will build a new version %s", new_version)

logging.info("Change directory into kodi-%s", upstream_rev)
os.chdir(f"kodi-{upstream_rev}")

locale.setlocale(locale.LC_ALL, "C")
now_ts = datetime.now(tz=timezone.utc).strftime("%a, %d %b %Y %T %z")

changelog_entry = f"""kodi ({new_version}) unstable; urgency=medium

  * Use APP_RENDER_SYSTEM=gles instead of desktop OpenGL

 -- Hugh Cole-Baker <sigmaris@gmail.com>  {now_ts}

"""

logging.info("Patching APP_RENDER_SYSTEM...")
with open("debian/rules", "r", encoding="utf-8") as infile:
    rules = infile.read()
new_rules = rules.replace("-DAPP_RENDER_SYSTEM=gl ", "-DAPP_RENDER_SYSTEM=gles ")
if new_rules == rules:
    fail("Could not find -DAPP_RENDER_SYSTEM=gl to patch!")
with open("debian/rules.new", "w", encoding="utf-8") as outfile:
    outfile.write(new_rules)
os.rename("debian/rules.new", "debian/rules")


logging.info("Patching changelog...")
with open("debian/changelog", "r", encoding="utf-8") as infile:
    changelog = infile.read()
with open("debian/changelog.new", "w", encoding="utf-8") as outfile:
    outfile.write(changelog_entry)
    outfile.write(changelog)
os.rename("debian/changelog.new", "debian/changelog")

patchdir = os.path.join(THISDIR, "patches")
for patchfile in os.listdir(patchdir):
    logging.info("Applying patch file %s...", patchfile)
    with open(os.path.join(patchdir, patchfile), "rb") as patch_fobj:
        subprocess.check_call("patch -p1".split(), stdin=patch_fobj)

logging.info("Rebuilding package...")
subprocess.check_call("dpkg-buildpackage -b -uc -us".split())

logging.info("All done!")
