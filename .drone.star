FILEBUCKET_ENV = {
    "FILEBUCKET_USER": "drone.io",
    "FILEBUCKET_PASSWORD": {"from_secret": "FILEBUCKET_PASSWORD"},
    "FILEBUCKET_SERVER": {"from_secret": "FILEBUCKET_SERVER"},
}
DEB_SCREENSAVERS = (
    ("asteroids", "20.1.0+ds1-2"),
    ("biogenesis", "20.1.0-2"),
    ("greynetic", "20.1.0+ds1-2"),
    ("pingpong", "20.1.0+ds1-2"),
    ("pyro", "20.1.0-2"),
    ("shadertoy", "20.1.0+ds1-2"),
)
DEB_VISUALIZATIONS = (
    ("fishbmc", "20.2.0+ds1-1"),
    ("pictureit", "20.2.0+ds1-1"),
    ("shadertoy", "20.3.0+ds1-1"),
    ("spectrum", "20.2.0+ds1-1"),
    ("waveform", "20.2.1+ds1-1"),
)

def main(ctx):
    base_version = "2:20.1+dfsg-1"
    artifact_prefix = "filebucket/"
    pipelines = []
    arch = "arm64"
    if "ci: kodi" in ctx.build.message:
        pipelines.append(kodi_pipeline(arch, base_version))
        # pipelines.append(kodi_pipeline("arm", base_version, "armhf"))
    if "ci: addons" in ctx.build.message:
        deb_visualizations_exclude = "|".join([name for (name, _version) in DEB_VISUALIZATIONS])
        deb_screensavers_exclude = "|".join([name for (name, _version) in DEB_SCREENSAVERS])
        pipelines.extend([
            git_addons_pipeline(
                arch, base_version, artifact_prefix, "build_audiodecoder_addons", "audiodecoder.* -audiodecoder.(fluidsynth|openmpt|sidplay)"
            ),
            git_addons_pipeline(
                arch, base_version, artifact_prefix, "build_screensaver_addons", "screensaver.* -screensaver.({})".format(deb_screensavers_exclude)
            ),
            git_addons_pipeline(
                arch, base_version, artifact_prefix, "build_visualization_addons", "visualization.* -visualization.({})".format(deb_visualizations_exclude)
            ),
            git_addons_pipeline(
                arch, base_version, artifact_prefix, "build_vfs_addons", "vfs.* -vfs.(libarchive|sftp)"
            ),
        ])
    if "ci: games" in ctx.build.message:
        pipelines.extend([
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro",        "^game\\\\.libretro$"),
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro_number", "^game\\\\.libretro\\\\.[0-9].*"),
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro_a",      "^game\\\\.libretro\\\\.a.*"),
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro_b",      "^game\\\\.libretro\\\\.b.*"),
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro_c",      "^game\\\\.libretro\\\\.c.*"),
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro_d_to_e", "^game\\\\.libretro\\\\.[d-e].*"),
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro_f",      "^game\\\\.libretro\\\\.f.*"),
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro_g_to_l", "^game\\\\.libretro\\\\.[g-l].*"),
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro_ma",     "^game\\\\.libretro\\\\.ma.*"),
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro_mb_z",   "^game\\\\.libretro\\\\.m[b-z].*"),
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro_n",      "^game\\\\.libretro\\\\.n.*"),
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro_o",      "^game\\\\.libretro\\\\.o.*"),
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro_p",      "^game\\\\.libretro\\\\.p.*"),
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro_q_to_r", "^game\\\\.libretro\\\\.[q-r].*"),
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro_s",      "^game\\\\.libretro\\\\.s.*"),
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro_t",      "^game\\\\.libretro\\\\.t.*"),
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro_u",      "^game\\\\.libretro\\\\.u.*"),
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro_v",      "^game\\\\.libretro\\\\.v.*"),
            git_addons_pipeline(arch, base_version, artifact_prefix, "build_game_libretro_w_to_z", "^game\\\\.libretro\\\\.[w-z].*"),
        ])
    return pipelines


def kodi_pipeline(drone_arch, base_version, deb_arch=None):
    if not deb_arch:
        deb_arch = drone_arch
    docker_img = "ghcr.io/sigmaris/kodibuilder:bookworm"
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
                "depends_on": ["prepare_kodi"],
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
                "depends_on": ["publish_kodi_config"],
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


def git_addons_pipeline(drone_arch, base_version, artifact_prefix, job_id, regex, deb_arch=None):
    if not deb_arch:
        deb_arch = drone_arch
    if deb_arch == "amd64":
        arch_triplet = "x86_64-linux-gnu"
    elif deb_arch == "arm64":
        arch_triplet = "aarch64-linux-gnu"
    elif deb_arch == "armhf":
        arch_triplet = "arm-linux-gnueabihf"
    docker_img = "ghcr.io/sigmaris/kodibuilder:bookworm"
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
                    ARTIFACT_PREFIX=artifact_prefix,
                    DEB_ARCH=deb_arch,
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
                    "apt-get -y -u -V install ./kodi-addons-dev_*.deb ./kodi-addons-dev-common_*.deb git libbz2-dev libgles2-mesa-dev libglm-dev libmodplug-dev libpcap-dev libprojectm-dev libwavpack-dev libxi-dev lsb-release python2",
                    "../builder-src/build_git_addons.sh",
                ],
                "depends_on": ["grab_source"],
            },

            # Publish addons to filebucket
            {
                "name": "publish_addons",
                "image": docker_img,
                "environment": FILEBUCKET_ENV,
                "commands": [
                    "cd /drone/kodi-build",
                    "/drone/builder-src/upload_artifacts.sh *.deb",
                ],
                "depends_on": ["build_addons"],
            },

            # Upload artifacts to Github release for tag builds
            {
                "name": "release_addons",
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
                "depends_on": ["build_addons"],
                "when": {
                    "event": "tag",
                },
            },
        ],
    }
