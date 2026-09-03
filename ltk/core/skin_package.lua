---@class SkeletonExtraDataSpec
---@field scale? number @ 缩放比例
---@field x_offset? number @ x方向百分比偏移量
---@field y_offset? number @ y方向百分比偏移量
---@field shown_anim? string @ 出场动画
---@field normal_anim? string @ 待机动画
---@field attack_anim? string @ 攻击动画（未适配）
---@field special_anim? string @ 特殊动画（未适配）
---@field bg_scale? number
---@field body_scale? number
---@field bg_x_offset? number
---@field bg_y_offset? number
---@field body_x_offset? number
---@field body_y_offset? number
---@field bg_shown_anim? string
---@field bg_normal_anim? string
---@field bg_attack_anim? string
---@field bg_special_anim? string
---@field body_shown_anim? string
---@field body_normal_anim? string
---@field body_attack_anim? string
---@field body_special_anim? string
---@field render_scale? number @ 渲染比例，比较大的或组件很多的骨骼适当调低一点这个
---@field static_bg? string @ 如果使用静态图片作为背景，则在这里输入静态图片名（带后缀），注意：files里也得有这个文件

--加载后的skin保存方式，一个武将的一个skin通过SkinContent类保存
---@class SkinContent
---@field name string
---@field is_skel boolean
---@field path string

---@class SkelSkinContent
---@field name string
---@field is_skel boolean
---@field path string
---@field files string[]
---@field bg? string
---@field body string
---@field extra_data? SkeletonExtraDataSpec

---@class SkinPackageContent
---@field enabled_generals string[]
---@field skins string[]

---@class SkelSkinPackageContent
---@field enabled_generals string[]
---@field skin_name string
---@field files string[]
---@field bg? string
---@field body string
---@field extra_data? SkeletonExtraDataSpec

---@class SkinPackageSpec
---@field path? string
---@field url? string -- 网络链接
---@field content SkinPackageContent[] | SkelSkinPackageContent[]

---@class SkinPackage : SkinPackageSpec, Object
SkinPackage = class("Base.SkinPackage")

function SkinPackage:initialize(spec)
  self.name = spec.name
  self.content = spec.content
end

return SkinPackage