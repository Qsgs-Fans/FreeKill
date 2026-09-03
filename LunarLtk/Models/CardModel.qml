import QtQuick
import Fk
import LunarLtk

// 此为某个游戏牌的UI数据
//
// 凭借这套数据可以造出各种外观的游戏牌

QtObject {
  id: root

  property int cardId   // 游戏牌的id
  property int virtId   // 若cardId为0（虚拟卡），则另设id以便与ui卡一一对应
  property int miscExpandId   // miscExpand专用

  // 获得牌的*唯一ID*，如果是虚拟牌则返回virtId，否则返回cardId
  readonly property int uniqueId: cardId === 0 ? virtId : cardId

  property var cardItem

  property string name: "slash" // 牌名
  property string trueName: "slash"
  property string virtName: "" // 被〖武神〗之类技能强制转化，或被当作其他牌使用时，此牌的实际牌名
  property int number // 点数
  property string suit // 花色
  property string color // 颜色
  property var picName : null // 卡片图像名

  property string extension

  // TODO 这俩没啥用途吧，再看
  property int type: 0
  property string subtype: ""

  property int attackRange: 0

  property bool known: true // 是否已知

  property list<var> marks: [] // 标记，详见PhotoModel
  property bool markVisible: false

  property string footnote: ""  // footnote, e.g. "A use card to B"
  property bool footnoteVisible: false

  property var cardTip: []
  property string prohibitReason: ""

  // 与UI交互相关
  property bool selectable: false
  property bool selected: false // 这个反过来被绑定

  // 重新getCardById并刷新数据
  function refreshData() {
    const data = Ltk.getCardData(cardId, true);
    const { name, extension, number, suit, color, type, subtype } = data;
    Object.assign(root, {
      name, extension, number, suit, color, type, subtype,
      virtName: data.virt_name ?? "",
      picName: data.pic_name ?? "",
      attackRange: data.attack_range ?? 0
    })
    known = Lua.selfPlayer.cardVisible(cardId);
    trueName = name.split("__").pop();
  }
  
  function updateCardTip() {
    const dataList = Ltk.getCardTip(cardId);
    // 翻译是个逻辑，这里要负责直接向ui呈送需要的文本
    for (const data of dataList) {
      data.content = Ltk.processPrompt(data.content);
    }
    cardTip = dataList;
  }

}

