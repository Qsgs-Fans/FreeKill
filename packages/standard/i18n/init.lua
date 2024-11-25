-- SPDX-License-Identifier: GPL-3.0-or-later

local pkgprefix = "packages/"
if UsingNewCore then pkgprefix = "packages/freekill-core/" end
dofile(pkgprefix .. "standard/i18n/zh_CN.lua")
dofile(pkgprefix .. "standard/i18n/en_US.lua")
dofile(pkgprefix .. "standard/i18n/vi_VN.lua")
