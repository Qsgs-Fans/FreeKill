import QtQuick 2.15
import QtQuick.Layouts 1.1
import QtGraphicalEffects 1.0

RowLayout {
    id: root

    property alias self: selfPhoto
    property alias handcardArea: handcardAreaItem
    property alias equipArea: selfPhoto.equipArea
    property alias delayedTrickArea: selfPhoto.delayedTrickArea
    property alias specialArea: selfPhoto.specialArea

    HandcardArea {
        id: handcardAreaItem
        Layout.fillWidth: true
        Layout.fillHeight: true
    }

    Photo {
        id: selfPhoto
    }

    Item { width: 5 }
}
