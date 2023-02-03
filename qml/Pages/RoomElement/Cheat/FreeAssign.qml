import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  anchors.fill: parent
  property var extra_data: ({})

  signal finish()

  Flickable {
    anchors.fill: parent
    contentHeight: childrenRect.height
    ScrollBar.vertical: ScrollBar {}
    ColumnLayout {
      Repeater {
        model: ListModel {
          id: packages
        }

        ColumnLayout {
          Text { text: Backend.translate(name) }
          GridLayout {
            columns: 5
            Repeater {
              model: JSON.parse(Backend.callLuaFunction("GetGenerals", [name]))
              Button {
                text: Backend.translate(modelData)
                onClicked: {
                  extra_data.card.name = modelData;
                  root.finish();
                }
              }
            }
          }
        }
      }
    }
  }

  function load() {
    let packs = JSON.parse(Backend.callLuaFunction("GetAllGeneralPack", []));
    packs.forEach((name) => packages.append({ name: name }));
  }

  Component.onCompleted: {
    load();
  }
}
