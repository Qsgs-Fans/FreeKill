import QtQuick
import Fk
import LunarLtk

QtObject {
  id: root

  property list<var> choices
  property list<var> allChoices
  property int minNum: 1
  property int maxNum: 1
  property bool cancelable: false
  property string skillName
  property string prompt
  property bool detailed : false
  property bool single : false

  property list<var> result: []

  signal accepted()
  signal rejected()

  readonly property string promptText: {
    const raw = Ltk.processPrompt(prompt || `#AskForChoice:::${skillName}`);
    return Lua.tr(raw);
  }

  readonly property bool feasible: {
    const len = result.length;
    return len >= minNum && len <= maxNum;
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

    if (minNum === 1 && maxNum === 1 && result.length === 1 && single) {
      accepted();
    }
  }
}
