import QtQuick
import Fk
import LunarLtk

QtObject {
  id: root

  property list<var> options: []
  property list<var> allOptions: []
  property int minNum: 1
  property int maxNum: 1
  property bool cancelable: false
  property string skillName: ""
  property string prompt: ""
  property bool single : false

  property bool enableOK: false // 强制启用OK选项，只在ActiveSkill里使用
  property bool acceptable: true // ActiveSkill会重新指定此属性
  property list<var> enabledOptions: options //用于refresh_interaction传入， 默认是options
  property list<var> result: []

  signal accepted()
  signal rejected()
  signal update(string option)

  readonly property string promptText: {
    const raw = Ltk.processPrompt(prompt || `#AskForOption:::${skillName}`);
    return Lua.tr(raw);
  }

  readonly property bool feasible: {
    const len = result.length;
    return len >= minNum && len <= maxNum && acceptable;
  }

  function toggleChoose(choice) {

    const idx = result.indexOf(choice);
    if (idx === -1) {
      result.push(choice);
    } else {
      result.splice(idx, 1);
    }

    if (result.length > maxNum) {
      result.splice(0, 1);
    }

    if (minNum === 1 && maxNum === 1 && result.length === 1 && single && !enableOK) {
      accepted();
    }
    if (enableOK) {
      update(choice);
    }
  }
}
