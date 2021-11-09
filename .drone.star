FILEBUCKET_ENV = {
    "FILEBUCKET_USER": "drone.io",
    "FILEBUCKET_PASSWORD": {"from_secret": "FILEBUCKET_PASSWORD"},
    "FILEBUCKET_SERVER": {"from_secret": "FILEBUCKET_SERVER"},
}

def main(ctx):
    base_version = "2:19.1+dfsg2-2"
    dev_url = "https://${FILEBUCKET_SERVER}/filebucket/"
    pipelines = []
    if "ci: kodi" in ctx.build.message:
        pipelines.append(kodi_pipeline("arm64", base_version))
        # pipelines.append(kodi_pipeline("arm", base_version, "armhf"))
    if "ci: addons" in ctx.build.message:
        pipelines.append(git_addons_pipeline("arm64", base_version, dev_url, "build_visualization_addons", "visualization.*"))
    return pipelines


def kodi_pipeline(drone_arch, base_version, deb_arch=None):
    if not deb_arch:
        deb_arch = drone_arch
    docker_img = "ghcr.io/sigmaris/kodibuilder:bullseye"
    return {
        "kind": "pipeline",
        "type": "docker",
        "name": "build_kodi_%s" % drone_arch,
        "platform": {
            "os": "linux",
            "arch": drone_arch,
        },
        "workspace": {
            "base": "/drone",
            "path": "builder-src",
        },
        "trigger": {
            "ref": [
                "refs/heads/*",
                "refs/tags/*",
            ]
        },
        "clone": {
            "depth": 1
        },
        "steps": [
            # Prepare Kodi sourcecode
            {
                "name": "prepare_kodi",
                "image": docker_img,
                "environment": {
                    "BASE_VERSION": base_version,
                    "DEB_ARCH": deb_arch,
                },
                "commands": [
                    "cd ..",
                    "mkdir kodi-build",
                    "cd kodi-build",
                    "../builder-src/prepare_kodi.sh",
                ],
            },

            # Publish kodi configured source to filebucket
            {
                "name": "publish_kodi_config",
                "image": docker_img,
                "environment": FILEBUCKET_ENV,
                "commands": [
                    "cd /drone/kodi-build",
                    "/drone/builder-src/upload_artifacts.sh *.tar.bz2",
                ],
                "depends_on": ["build_kodi"],
            },

            # Build Kodi
            {
                "name": "build_kodi",
                "image": docker_img,
                "environment": {
                    "BASE_VERSION": base_version,
                    "DEB_ARCH": deb_arch,
                },
                "commands": [
                    "cd /drone/kodi-build",
                    "../builder-src/build_kodi.sh",
                ],
            },

            # Publish kodi build artifacts to filebucket
            {
                "name": "publish_kodi_debs",
                "image": docker_img,
                "environment": FILEBUCKET_ENV,
                "commands": [
                    "cd /drone/kodi-build",
                    "/drone/builder-src/upload_artifacts.sh *.deb",
                ],
                "depends_on": ["build_kodi"],
            },

            # Upload artifacts to Github release for tag builds
            {
                "name": "release_kodi",
                "image": "ghcr.io/sigmaris/drone-github-release:latest",
                "settings": {
                    "api_key": {
                        "from_secret": "github_token",
                    },
                    "files": [
                        "/drone/kodi-build/*.deb",
                        "/drone/kodi-build/*.tar.bz2",
                    ],
                    "checksum": [
                        "md5",
                        "sha1",
                        "sha256",
                    ]
                },
                "depends_on": ["build_kodi"],
                "when": {
                    "event": "tag",
                },
            },
        ]
    }


def git_addons_pipeline(drone_arch, base_version, dev_url, job_id, regex, deb_arch=None):
    if not deb_arch:
        deb_arch = drone_arch
    if deb_arch == "amd64":
        arch_triplet = "x86_64-linux-gnu"
    elif deb_arch == "arm64":
        arch_triplet = "aarch64-linux-gnu"
    elif deb_arch == "armhf":
        arch_triplet = "arm-linux-gnueabihf"
    docker_img = "ghcr.io/sigmaris/kodibuilder:bullseye"
    return {
        "kind": "pipeline",
        "type": "docker",
        "name": job_id,
        "platform": {
            "os": "linux",
            "arch": drone_arch,
        },
        "workspace": {
            "base": "/drone",
            "path": "builder-src",
        },
        "trigger": {
            "ref": [
                "refs/heads/*",
                "refs/tags/*",
            ]
        },
        "clone": {
            "depth": 1
        },
        "steps": [
            # Retrieve source
            {
                "name": "grab_source",
                "image": docker_img,
                "environment": dict(
                    BASE_VERSION=base_version,
                    DEV_URL=dev_url,
                    DEB_ARCH=deb_arch
                    **FILEBUCKET_ENV
                ),
                "commands": [
                    "cd ..",
                    "mkdir kodi-build",
                    "cd kodi-build",
                    "../builder-src/grab_source.sh",
                ],
            },

            # Build all matching addons
            {
                "name": "build_addons",
                "image": docker_img,
                "environment": dict(
                    BASE_VERSION=base_version,
                    ARCH_TRIPLET=arch_triplet,
                    ADDONS_REGEX=regex,
                ),
                "commands": [
                    "cd /drone/kodi-build",
                    "../builder-src/build_git_addons.sh",
                ],
            },
        ],
    }
