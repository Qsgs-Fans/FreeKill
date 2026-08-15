import QtQuick
import LunarLtk

QtObject {
  id: root

  property string prompt
  property list<var> cardData // var为如此list: [ name, ids ]
  property var cardVisibility // 一个object 牌id到是否可见的映射

  property int selectedId: 0

  readonly property var cardModels: {
    const dict = {};
    const visibleData = cardVisibility ?? {};

    for (const tab of cardData) {
      for (const cid of tab[1]) {
        dict[cid] = Ltk.createCardModel(cid, {
          known: visibleData[cid.toString()] !== false,
        });
      }
    }
    return dict;
  }

  readonly property string promptText: {
    return Ltk.processPrompt(prompt)
  }

  signal accepted()
  signal rejected()

  function shuffleIds() {
    const output = [];
    cardData.forEach((cardArrs) => {
      let piles = [];
      const origCards = cardArrs[1];
      if (cardVisibility) {
        const invisible = [];
        for (const cid of origCards) {
          if (cardVisibility[cid.toString()] === false)
            invisible.push(cid);
          else
            piles.push(cid);
        }

        // 洗牌invisible
        for (let i = invisible.length - 1; i > 0; i--) {
          const j = Math.floor(Math.random() * (i + 1));
          [invisible[i], invisible[j]] = [invisible[j], invisible[i]];
        }

        piles.push(...invisible);
      } else piles = origCards;
      output.push([cardArrs[0], piles]);
    });
    return output;
  }
}
