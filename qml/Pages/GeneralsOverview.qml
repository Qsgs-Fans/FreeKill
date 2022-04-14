import QtQuick 2.15

ListView {
    id: root
    anchors.fill: parent
    model: ListModel {
        id: packages
    }

    delegate: ColumnLayout {
        width: parent.width
    }

    Component.onCompleted: {
        let packs = Backend.getAllPackageNames()
        packs.forEach((name) => packages.append({ name: name }))
    }
}