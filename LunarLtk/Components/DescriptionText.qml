import QtQuick
import Fk

TextEdit {
  font.pixelSize: 18

  readOnly: true
  selectByKeyboard: true
  selectByMouse: false
  wrapMode: TextEdit.WordWrap
  textFormat: TextEdit.RichText
  property var savedtext: []
  function clearSavedText() {
    savedtext = [];
  }
  onLinkActivated: (link) => {
    if (link === "back") {
      text = savedtext.pop();
    } else {
      savedtext.push(text);
      text = '<a href="back">' + Lua.tr("Click to back") + '</a><br>' + Lua.tr(link);
    }
  }
}

