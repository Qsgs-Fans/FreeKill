import QtQuick
import Fk
import LunarLtk

// 此为某个武将牌的UI数据
//
// 凭借这套数据可以造出各种外观的武将牌

QtObject {
  id: root

  property var cardItem

  // 武将局内信息
  property string name: "diaochan" // 武将名
  property string kingdom: "qun" // 势力
  property string subkingdom: "" // 子势力，常见于多势力武将
  property int hp: 0 // 武将初始体力值
  property int maxHp: 0 // 武将初始体力上限
  property int shieldNum: 0 // 武将初始护甲值
  property string skin: "" // 皮肤名，默认为空，表示使用默认皮肤

  // 武将牌额外信息（子扩展名等）
  property string prefix: "" // 武将子扩展包名缩写，用于简略显示

  // 国战专用
  // property bool heg: false // 是否为国战武将
  // 老代码太耦了不好看所以直接填false是吧
  // FIXME: 藕！！
  property bool heg: name.startsWith('hs__') || name.startsWith('ld__') ||
                     name.includes('heg__')

  property int mainMaxHp: 0 // 国战主将额外体力上限
  property int deputyMaxHp: 0 // 国战副将额外体力上限
  property int inPosition: 0 // 选将时的指示器，0=无，1=主将，-1=副将
  property bool hasCompanion: false // 是否显示珠联璧合标记

  // 卡牌显示信息
  property bool known: true // 是否已知（不可知则显示牌背）
  property bool detailed: true // 是否显示详细信息（如体力值等）
  property bool showIsFavorite: true // 是否显示收藏标记
  property string footnote: ""  // 脚注，可能有用（
  property bool footnoteVisible: false

  property string prohibitReason: ""

  // 与UI交互相关
  property bool selectable: false
  property bool selected: false // 这个反过来被绑定

  // 皮肤
  property bool showSkin: false
  property string skinName: (Config.enabledSkins[name] && showSkin) ? Config.enabledSkins[name] : "" //当前使用的皮肤

  // 次生参数
  readonly property var frontSkin: {
    return skinName ? Ltk.getFullSkinPath(name, Config.enabledSkins[name]) : SkinBank.getGeneralPicture(name);
  }
  readonly property var backSkin: {
    return SkinBank.generalCardDir + 'card-back';
  }

  // Config内容改变不会触发skinName改变，必须手动触发
  function refreshSkin() {
    showSkinChanged()
  }
}

