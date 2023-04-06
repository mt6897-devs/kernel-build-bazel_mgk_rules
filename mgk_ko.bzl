load(
    "//build/kernel/kleaf:kernel.bzl",
    "kernel_module",
)
load(
    ":mgk.bzl",
    "kernel_versions",
)

def define_mgk_ko(
        name,
        srcs = None,
        outs = None,
        deps = []):
    if srcs == None:
        srcs = native.glob(
            [
                "**/*.c",
                "**/*.h",
                "**/Kbuild",
                "**/Makefile",
            ],
            exclude = [
                ".*",
                ".*/**",
            ],
        )
    if outs == None:
        outs = [name + ".ko"]
    for version in kernel_versions:
        for build in ["eng", "userdebug", "user", "ack"]:
            kernel_module(
                name = "{}.{}.{}".format(name, version, build),
                srcs = srcs,
                outs = outs,
                kernel_build = "//kernel_device_modules-{}:mgk.{}".format(version, build),
                deps = [
                    "//kernel_device_modules-{}:mgk_modules.{}".format(version, build),
                ] + ["{}.{}.{}".format(m, version, build) for m in deps],
            )

