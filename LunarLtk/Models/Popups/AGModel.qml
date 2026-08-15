import QtQuick
import Fk
import LunarLtk

QtObject {
  id: root

  property list<var> cards // CardModel[]
  property string currentPlayerName: ""
  property bool interactive: false
  property string promptText: Lua.tr("Please choose cards")

  property int result

  signal accepted()

  function addIds(ids) {
    ids.forEach((id) => {
      const data = Ltk.createCardModel(id);
      data.selectable = true;
      data.footnote = "";
      cards.push(data);
    });
  }

  function takeAG(g, cid) {
    for (const model of cards) {
      if (model.cardId !== cid) continue;
      model.footnote = g;
      model.selectable = false;
      break;
    }
  }

  function selectCard(model) {
    if (root.interactive && model.selectable) {
      result = model.cardId;
      accepted();
    }
  }
}
