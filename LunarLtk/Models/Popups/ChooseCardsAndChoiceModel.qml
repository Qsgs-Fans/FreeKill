import QtQuick
import LunarLtk
import Fk

QtObject {
  id: root

  property list<var> cards: []
  property list<var> choices: []
  property list<var> cancelChoices: []
  property string prompt: ""
  property int minNum: 1
  property int maxNum: 1
  property string filterSkel: ""
  property list<var> disabledCards: []
  property var extraData

  property var result: ({ cards: [], choice: "" })

  signal accepted()
  signal rejected()

  readonly property string promptText: {
    if (prompt === "") return Lua.tr("$ChooseCard");
    return Ltk.processPrompt(prompt);
  }

  function choiceEnabled(selectedCards, choice, index) {
    if (!(selectedCards && selectedCards.length >= minNum && selectedCards.length <= maxNum)) {
      return false;
    }
    if (index === 0) return true;
    if (filterSkel !== "") {
      const cardsText = "{" + selectedCards.join(",") + "}";
      const extraText = JSON.stringify(extraData ?? null);
      const fn = Lua.fn(`Fk.skill_skels['${filterSkel}'].extra.choiceFilter`);
      return fn(selectedCards, choice, extraData);
    }
    return true;
  }

  //选择选项
  function toggleChoose(choice) {
    result.choice = choice;
    accepted();
  }

}
