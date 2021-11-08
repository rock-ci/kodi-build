def main(ctx):
    base_version = "2:19.1+dfsg2-2"
    dev_url = "https://${FILEBUCKET_SERVER}/filebucket/"
    pipelines = []
    if "ci: addons" in ctx.build.message:
        pipelines.append(addons_pipeline("arm64", base_version, dev_url, "build_visualization_addons", "visualization.*"))
    if "ci: kodi" in ctx.build.message:
        pipelines.append(kodi_pipeline("arm64", base_version))
        pipelines.append(kodi_pipeline("arm", base_version))
    return pipelines


def kodi_pipeline(drone_arch, base_version):
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
            # Build Kodi alone
            {
                "name": "build_kodi",
                "image": docker_img,
                "commands": [
                    "cd ..",
                    "mkdir kodi-build",
                    "cd kodi-build",
                    "../builder-src/build_kodi.sh '%s'" % base_version,
                ],
            },

            # Publish kodi build artifacts to filebucket for non-tag builds
            {
                "name": "publish_kodi",
                "image": docker_img,
                "environment": {
                    "FILEBUCKET_USER": "drone.io",
                    "FILEBUCKET_PASSWORD": {"from_secret": "FILEBUCKET_PASSWORD"},
                    "FILEBUCKET_SERVER": {"from_secret": "FILEBUCKET_SERVER"},
                },
                "commands": [
                    "cd /drone/kodi-build",
                    "/drone/builder-src/upload_artifacts.sh",
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


def addons_pipeline(drone_arch, base_version, dev_url, job_id, regex, deb_arch=None):
    if not deb_arch:
        deb_arch = drone_arch
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
                "environment": {
                    "FILEBUCKET_USER": "drone.io",
                    "FILEBUCKET_PASSWORD": {"from_secret": "FILEBUCKET_PASSWORD"},
                    "FILEBUCKET_SERVER": {"from_secret": "FILEBUCKET_SERVER"},
                },
                "commands": [
                    "cd ..",
                    "mkdir kodi-build",
                    "cd kodi-build",
                    '../builder-src/grab_source.sh "%s" "%s" "%s"' % (base_version, dev_url, deb_arch),
                ],
            },
        ],
    }
