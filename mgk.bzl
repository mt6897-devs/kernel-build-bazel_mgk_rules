load(
    "@bazel_skylib//rules:common_settings.bzl",
    "bool_flag",
    "string_flag",
)
load(
    "//build/kernel/kleaf:constants.bzl",
    "aarch64_outs",
)
load(
    "//build/kernel/kleaf:kernel.bzl",
    "kernel_build",
    "kernel_images",
    "kernel_module",
    "kernel_modules_install",
)
load(
    "//build/bazel_common_rules/dist:dist.bzl",
    "copy_to_dist_dir",
)


def define_mgk(
        name,
        kleaf_modules,
        common_modules,
        device_modules,
        device_eng_modules,
        device_userdebug_modules,
        device_user_modules):
    bool_flag(name = "entry_level_config", build_setting_default = False)
    bool_flag(name = "fpga_config"       , build_setting_default = False)
    bool_flag(name = "kasan_config"      , build_setting_default = False)
    bool_flag(name = "khwasan_config"    , build_setting_default = False)
    bool_flag(name = "vulscan_config"    , build_setting_default = False)
    native.config_setting(name = "entry_level_set", flag_values = {":entry_level_config": "true"})
    native.config_setting(name = "fpga_set"       , flag_values = {":fpga_config"       : "true"})
    native.config_setting(name = "kasan_set"      , flag_values = {":kasan_config"      : "true"})
    native.config_setting(name = "khwasan_set"    , flag_values = {":khwasan_config"    : "true"})
    native.config_setting(name = "vulscan_set"    , flag_values = {":vulscan_config"    : "true"})
    mgk_defconfig_overlays = \
        select({":entry_level_set": ["entry_level.config"], "//conditions:default": []}) + \
        select({":fpga_set"       : ["fpga.config"]       , "//conditions:default": []}) + \
        select({":kasan_set"      : ["kasan.config"]      , "//conditions:default": []}) + \
        select({":khwasan_set"    : ["khwasan.config"]    , "//conditions:default": []}) + \
        select({":vulscan_set"    : ["vulscan.config"]    , "//conditions:default": []})

    string_flag(name = "kernel_version" , build_setting_default = "5.15")
    native.config_setting(name = "kernel_version_5_15"    , flag_values = {":kernel_version": "5.15"})
    native.config_setting(name = "kernel_version_mainline", flag_values = {":kernel_version": "mainline"})

    mgk_defconfig = name + "_defconfig"

    native.filegroup(
        name = "mgk_sources",
        srcs = native.glob(
            ["**"],
            exclude = [
                ".*",
                ".*/**",
                "BUILD.bazel",
                "**/*.bzl",
                "build.config.*",
            ],
        ),
    )
    native.filegroup(
        name = "mgk_configs",
        srcs = native.glob([
            "arch/arm64/configs/*",
            "kernel/configs/**",
            "**/Kconfig",
            "drivers/cpufreq/Kconfig.*",
        ]) + [
            "Kconfig.ext",
        ],
    )
    native.filegroup(
        name = "mgk_dt-bindings",
        srcs = native.glob([
            "include/dt-bindings/**",
            "include/dtc/**",
        ]),
    )

    for build in ["eng", "userdebug", "user", "ack"]:
        if build == "ack":
            # for device module tree
            mgk_build_config(
                name = "mgk_build_config.{}".format(build),
                kernel_dir = select({
                    ":kernel_version_5_15"    : "common-5.15",
                    ":kernel_version_mainline": "common-mainline",
                    "//conditions:default"    : "common",
                }),
                device_modules_dir = select({
                    ":kernel_version_5_15"    : "kernel_device_modules-5.15",
                    ":kernel_version_mainline": "kernel_device_modules-mainline",
                    "//conditions:default"    : "kernel_device_modules",
                }),
                defconfig = mgk_defconfig,
                defconfig_overlays = mgk_defconfig_overlays,
                build_config_overlays = [],
                build_variant = "user",
                kleaf_modules = kleaf_modules,
                gki_mixed_build = True,
            )
            # for kernel tree
            # define by ACK
        else:
            # for device module tree
            mgk_build_config(
                name = "mgk_build_config.{}".format(build),
                kernel_dir = select({
                    ":kernel_version_5_15"    : "kernel-5.15",
                    ":kernel_version_mainline": "kernel-mainline",
                    "//conditions:default"    : "kernel",
                }),
                device_modules_dir = select({
                    ":kernel_version_5_15"    : "kernel_device_modules-5.15",
                    ":kernel_version_mainline": "kernel_device_modules-mainline",
                    "//conditions:default"    : "kernel_device_modules",
                }),
                defconfig = mgk_defconfig,
                defconfig_overlays = mgk_defconfig_overlays,
                build_config_overlays = [],
                build_variant = build,
                kleaf_modules = kleaf_modules,
                gki_mixed_build = True,
            )
            # for kernel tree
            mgk_build_config(
                name = "build_config.{}".format(build),
                kernel_dir = select({
                    ":kernel_version_5_15"    : "kernel-5.15",
                    ":kernel_version_mainline": "kernel-mainline",
                    "//conditions:default"    : "kernel",
                }),
                device_modules_dir = select({
                    ":kernel_version_5_15"    : "kernel_device_modules-5.15",
                    ":kernel_version_mainline": "kernel_device_modules-mainline",
                    "//conditions:default"    : "kernel_device_modules",
                }),
                defconfig = mgk_defconfig,
                defconfig_overlays = mgk_defconfig_overlays,
                build_config_overlays = [],
                build_variant = build,
                kleaf_modules = kleaf_modules,
                gki_mixed_build = False,
            )

        if build == "ack":
            kernel_build(
                name = "mgk.{}".format(build),
                srcs = select({
                    ":kernel_version_5_15"    : ["//common-5.15:kernel_aarch64_sources"],
                    ":kernel_version_mainline": ["//common-mainline:kernel_aarch64_sources"],
                    "//conditions:default"    : ["//common:kernel_aarch64_sources"],
                }) + [
                    ":mgk_sources",
                ],
                outs = [
                ],
                module_outs = common_modules,
                build_config = ":mgk_build_config.{}".format(build),
                kconfig_ext = "Kconfig.ext",
                base_kernel = select({
                    ":kernel_version_5_15"    : "//common-5.15:kernel_aarch64_debug",
                    ":kernel_version_mainline": "//common-mainline:kernel_aarch64_debug",
                    "//conditions:default"    : None,
                }),
            )
        else:
            kernel_build(
                name = "mgk.{}".format(build),
                srcs = select({
                    ":kernel_version_5_15"    : ["//kernel-5.15:kernel_aarch64_sources"],
                    ":kernel_version_mainline": ["//kernel-mainline:kernel_aarch64_sources"],
                    "//conditions:default"    : ["//kernel:kernel_aarch64_sources"],
                }) + [
                    ":mgk_sources",
                ],
                outs = [
                ],
                module_outs = common_modules,
                build_config = ":mgk_build_config.{}".format(build),
                kconfig_ext = "Kconfig.ext",
                base_kernel = select({
                    ":kernel_version_5_15"    : "//kernel-5.15:kernel_aarch64.{}".format(build),
                    ":kernel_version_mainline": "//kernel-mainline:kernel_aarch64.{}".format(build),
                    "//conditions:default"    : "//kernel:kernel_aarch64.{}".format(build),
                }),
            )
        kernel_modules_install(
            name = "mgk_modules_install.{}".format(build),
            kernel_modules = [
                ":mgk_modules.{}".format(build),
            ] + ["{}.{}".format(m, build) for m in kleaf_modules],
            kernel_build = ":mgk.{}".format(build),
        )
        if build == "ack":
            copy_to_dist_dir(
                name = "mgk_dist.{}".format(build),
                data = select({
                    ":kernel_version_5_15"    : ["//common-5.15:kernel_aarch64_debug"],
                    ":kernel_version_mainline": ["//common-mainline:kernel_aarch64_debug"],
                    "//conditions:default"    : [],
                }) + [
                    ":mgk.{}".format(build),
                    ":mgk_modules_install.{}".format(build),
                ],
                flat = False,
            )
        else:
            copy_to_dist_dir(
                name = "mgk_dist.{}".format(build),
                data = select({
                    ":kernel_version_5_15"    : ["//kernel-5.15:kernel_aarch64.{}".format(build)],
                    ":kernel_version_mainline": ["//kernel-mainline:kernel_aarch64.{}".format(build)],
                    "//conditions:default"    : ["//kernel:kernel_aarch64.{}".format(build)],
                }) + [
                    ":mgk.{}".format(build),
                    ":mgk_modules_install.{}".format(build),
                ],
                flat = False,
            )

    kernel_module(
        name = "mgk_modules.eng",
        srcs = [":mgk_sources"],
        outs = device_modules + device_eng_modules,
        kernel_build = ":mgk.eng",
    )
    kernel_module(
        name = "mgk_modules.userdebug",
        srcs = [":mgk_sources"],
        outs = device_modules + device_userdebug_modules,
        kernel_build = ":mgk.userdebug",
    )
    kernel_module(
        name = "mgk_modules.user",
        srcs = [":mgk_sources"],
        outs = device_modules + device_user_modules,
        kernel_build = ":mgk.user",
    )
    kernel_module(
        name = "mgk_modules.ack",
        srcs = [":mgk_sources"],
        outs = device_modules + device_user_modules,
        kernel_build = ":mgk.ack",
    )


def _mgk_build_config_impl(ctx):
    ext_content = []
    ext_content.append("EXT_MODULES=\"")
    ext_content.append(ctx.attr.device_modules_dir)
    has_fpsgo = False
    has_met = False
    for m in ctx.attr.kleaf_modules:
        path = m.partition(":")[0].removeprefix("//")
        if "fpsgo" in path:
            has_fpsgo = True
        elif "met_drv" in path:
            has_met = True
        else:
            ext_content.append(path)
    ext_content.append("\"")
    if has_fpsgo:
        ext_content.append("""
if [ -d "vendor/mediatek/kernel_modules/fpsgo_int" ]; then
EXT_MODULES+=" vendor/mediatek/kernel_modules/fpsgo_int"
else
EXT_MODULES+=" vendor/mediatek/kernel_modules/fpsgo_cus"
fi""")
    if has_met:
        ext_content.append("")
        ext_content.append("EXT_MODULES+=\" vendor/mediatek/kernel_modules/met_drv_v3\"")
        ext_content.append("""if [ -d "vendor/mediatek/kernel_modules/met_drv_secure_v3" ]; then
EXT_MODULES+=" vendor/mediatek/kernel_modules/met_drv_secure_v3"
fi""")
        ext_content.append("EXT_MODULES+=\" vendor/mediatek/kernel_modules/met_drv_v3/met_api\"")
    content = []
    content.append("DEVICE_MODULES_DIR={}".format(ctx.attr.device_modules_dir))
    content.append("KERNEL_DIR={}".format(ctx.attr.kernel_dir))
    #content.append("DEVICE_MODULES_REL_DIR=$(rel_path {} {})".format(ctx.attr.device_modules_dir, ctx.attr.kernel_dir))
    content.append("DEVICE_MODULES_REL_DIR=../{}".format(ctx.attr.device_modules_dir))
    content.append("""
. ${ROOT_DIR}/${KERNEL_DIR}/build.config.common
. ${ROOT_DIR}/${KERNEL_DIR}/build.config.gki
. ${ROOT_DIR}/${KERNEL_DIR}/build.config.aarch64

DEVICE_MODULES_PATH="\\$(srctree)/\\$(DEVICE_MODULES_REL_DIR)"
DEVCIE_MODULES_INCLUDE="-I\\$(DEVICE_MODULES_PATH)/include"
""")
    defconfig = []
    defconfig.append("${ROOT_DIR}/${KERNEL_DIR}/arch/arm64/configs/gki_defconfig")
    defconfig.append("${ROOT_DIR}/" + ctx.attr.device_modules_dir + "/arch/arm64/configs/${DEFCONFIG}")
    if ctx.attr.defconfig_overlays:
        defconfig.extend(ctx.attr.defconfig_overlays)
    if ctx.attr.build_variant == "eng":
        defconfig.append("${ROOT_DIR}/" + ctx.attr.device_modules_dir + "/kernel/configs/eng.config")
    elif ctx.attr.build_variant == "userdebug":
        defconfig.append("${ROOT_DIR}/" + ctx.attr.device_modules_dir + "/kernel/configs/userdebug.config")
    content.append("DEFCONFIG={}".format(ctx.attr.defconfig))
    content.append("PRE_DEFCONFIG_CMDS=\"KCONFIG_CONFIG=${ROOT_DIR}/${KERNEL_DIR}/arch/arm64/configs/${DEFCONFIG} ${ROOT_DIR}/${KERNEL_DIR}/scripts/kconfig/merge_config.sh -m -r " + " ".join(defconfig) + "\"")
    content.append("POST_DEFCONFIG_CMDS=\"rm -f ${ROOT_DIR}/${KERNEL_DIR}/arch/arm64/configs/${DEFCONFIG}\"")
    content.append("")
    content.extend(ext_content)
    content.append("")

    if ctx.attr.gki_mixed_build:
        content.append("MAKE_GOALS=\"modules\"")
        content.append("FILES=\"\"")
    else:
        content.append("MAKE_GOALS=\"${MAKE_GOALS} Image.lz4 Image.gz\"")
        content.append("FILES=\"${FILES} arch/arm64/boot/Image.lz4 arch/arm64/boot/Image.gz\"")

    build_config_file = ctx.actions.declare_file("{}/build.config".format(ctx.attr.name))
    ctx.actions.write(
        output = build_config_file,
        content = "\n".join(content) + "\n",
    )
    return DefaultInfo(files = depset([build_config_file]))


mgk_build_config = rule(
    implementation = _mgk_build_config_impl,
    doc = "Defines a kernel build.config target.",
    attrs = {
        "kernel_dir": attr.string(mandatory = True),
        "device_modules_dir": attr.string(mandatory = True),
        "defconfig": attr.string(mandatory = True),
        "defconfig_overlays": attr.string_list(),
        "build_config_overlays": attr.string_list(),
        "kleaf_modules": attr.string_list(),
        "build_variant": attr.string(mandatory = True),
        "gki_mixed_build": attr.bool(),
    },
)
