import QtQuick

Flickable {
  id: root
  property alias font: textEdit.font
  property alias text: textEdit.text
  property alias color: textEdit.color
  property alias textFormat: textEdit.textFormat

  flickableDirection: Flickable.VerticalFlick
  contentWidth: textEdit.width
  contentHeight: textEdit.height
  clip: true

  TextEdit {
    id: textEdit

    width: root.width
    clip: true
    readOnly: true
    selectByKeyboard: true
    selectByMouse: true
    wrapMode: TextEdit.WrapAnywhere
    textFormat: TextEdit.RichText
  }

  function append(text) {
    let autoScroll = atYEnd;
    textEdit.append(text);
    if (autoScroll && contentHeight > contentY + height) {
      contentY = contentHeight - height;
    }
  }
}
