#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=X00TD
VENDOR=asus

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        # Fix jar path
    product/etc/permissions/qti_fingerprint_interface.xml)
        sed -i 's|/system/framework/|/system/product/framework/|g' "${2}"
        ;;
    # Rename to fp service avoid conflicts
    vendor/etc/init/android.hardware.biometrics.fingerprint@2.1-service_asus.rc)
        sed -i 's|android.hardware.biometrics.fingerprint@2.1-service|android.hardware.biometrics.fingerprint@2.1-service_asus|g' "${2}"
        ;;
    # remove android.hidl.base dependency
    vendor/lib/hw/camera.sdm660.so)
        "${PATCHELF}" --remove-needed "android.hidl.base@1.0.so" "${2}"
	;;
    # remove android.hidl.base dependency
    system_ext/lib64/libfm-hci.so | system_ext/lib64/libwfdnative.so | system_ext/lib/libfm-hci.so | system_ext/lib/libwfdnative.so)
        "${PATCHELF}" --remove-needed "android.hidl.base@1.0.so" "${2}"
	;;
    system_ext/etc/init/dpmd.rc)
        sed -i "s|/system/product/bin/|/system/system_ext/bin/|g" "${2}"
        ;;
    system_ext/etc/permissions/com.qti.dpmframework.xml | system_ext/etc/permissions/dpmapi.xml | system_ext/etc/permissions/telephonyservice.xml)
        sed -i "s|/system/product/framework/|/system/system_ext/framework/|g" "${2}"
        ;;
    system_ext/etc/permissions/qcrilhook.xml)
        sed -i 's|/product/framework/qcrilhook.jar|/system_ext/framework/qcrilhook.jar|g' "${2}"
        ;;
    system_ext/lib64/libdpmframework.so)
        "${PATCHELF}" --replace-needed "libcutils.so" "libcutils-v29.so" "${2}"
        "${PATCHELF}" --add-needed "libcutils.so" "${2}"
        ;;
    system/lib/libwfdaudioclient.so)
        "${PATCHELF}" --set-soname "libwfdaudioclient.so" "${2}"
         ;;
    system/lib/libwfdmediautils.so)
        "${PATCHELF}" --set-soname "libwfdmediautils.so" "${2}"
         ;;
    system/lib/libwfdmmsink.so)
        "${PATCHELF}" --add-needed "libwfdaudioclient.so" "${2}"
        "${PATCHELF}" --add-needed "libwfdmediautils.so" "${2}"
         ;;
    esac
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
