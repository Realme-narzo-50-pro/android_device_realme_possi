#
# Copyright (C) 2024 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit some common Lineage stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# Inherit from ossi device
$(call inherit-product, device/realme/RMX3395/device.mk)

PRODUCT_DEVICE := RMX3395
PRODUCT_NAME := lineage_RMX3395
PRODUCT_BRAND := realme
PRODUCT_MODEL := RMX3395
PRODUCT_MANUFACTURER := realme

PRODUCT_GMS_CLIENTID_BASE := android-oplus

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="sys_mssi_64_cn_armv82-user 13 TP1A.220905.001 1705389919836 release-keys"

BUILD_FINGERPRINT := oplus/ossi/ossi:13/TP1A.220905.001/1705389919836:user/release-keys
