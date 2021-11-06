def main(ctx):
    base_version = "2:19.1+dfsg2-2"
    return kodi_pipeline("arm64", base_version)


def kodi_pipeline(drone_arch, base_version):
    docker_img = "ghcr.io/sigmaris/kodibuilder:bullseye"
    return {
        "kind": "pipeline",
        "type": "docker",
        "name": "build_kodi",
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
                    "../builder-src/build_kodi.py %s" % base_version,
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
                "when": {
                    "event": {"exclude": "tag"},
                },
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
