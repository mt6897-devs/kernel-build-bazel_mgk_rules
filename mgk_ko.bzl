load(
    "//build/kernel/kleaf:kernel.bzl",
    "kernel_module",
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
    # FIXME
    device_modules_dir = "kernel_device_modules-mainline"
    if outs == None:
        outs = [name + ".ko"]
    for build in ["eng", "userdebug", "user", "ack"]:
        kernel_module(
            name = "{}.{}".format(name, build),
            srcs = srcs,
            outs = outs,
            kernel_build = "//{}:mgk.{}".format(device_modules_dir, build),
            deps = [
                "//{}:mgk_modules.{}".format(device_modules_dir, build),
            ] + ["{}.{}".format(m, build) for m in deps],
        )

