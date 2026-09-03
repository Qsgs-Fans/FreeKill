pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

ActionRow {
  id: root

  property bool editable: false
  property int from
  property int to
  property int value
  property list<var> items: []

  suffixComponent: SpinBox {
    id: spinBox
    editable: root.editable
    from: root.items.length > 0 ? 0 : root.from
    to: root.items.length > 0 ? root.items.length - 1 : root.to
    value: root.value

    property bool _syncing: false
    property bool _syncScheduled: false

    function itemIndexFromValue(value) {
      if (root.items.length === 0) return Number(value) || 0;

      const stringValue = String(value);
      for (let i = 0; i < root.items.length; ++i) {
        if (String(root.items[i]) === stringValue) return i;
      }

      const numericValue = Number(value);
      if (!isNaN(numericValue)) {
        let bestIndex = 0;
        let bestDiff = Number.MAX_VALUE;
        for (let i = 0; i < root.items.length; ++i) {
          const itemValue = Number(root.items[i]);
          if (isNaN(itemValue)) continue;
          const diff = Math.abs(itemValue - numericValue);
          if (diff < bestDiff) {
            bestDiff = diff;
            bestIndex = i;
          }
        }
        return bestIndex;
      }

      return 0;
    }

    function itemValueFromIndex(index) {
      if (root.items.length === 0) return Number(index) || 0;
      const safeIndex = Number(index);
      if (!isFinite(safeIndex)) return root.items[0];
      const clampedIndex = Math.min(Math.max(Math.floor(safeIndex), 0), root.items.length - 1);
      return Number(root.items[clampedIndex]) || root.items[clampedIndex];
    }

    function clampIndex(index) {
      if (root.items.length > 0) {
        return Math.min(Math.max(Math.floor(Number(index) || 0), 0), root.items.length - 1);
      }
      return Math.min(Math.max(Number(index) || 0, root.from), root.to);
    }

    function syncFromRoot() {
      spinBox._syncScheduled = false;
      spinBox._syncing = true;

      try {
        if (root.items.length > 0) {
          const itemIndex = clampIndex(itemIndexFromValue(root.value));
          const itemValue = itemValueFromIndex(itemIndex);

          spinBox.value = -1;
          spinBox.value = itemIndex;

          if (root.value !== itemValue) {
            root.value = itemValue;
          }
        } else {
          const boundedValue = Math.min(Math.max(root.value, root.from), root.to);

          spinBox.value = -1;
          spinBox.value = boundedValue;

          if (root.value !== boundedValue) {
            root.value = boundedValue;
          }
        }
      } finally {
        spinBox._syncing = false;
      }
    }

    function scheduleSyncFromRoot() {
      spinBox._syncing = true;
      if (spinBox._syncScheduled) {
        return;
      }
      spinBox._syncScheduled = true;
      Qt.callLater(spinBox.syncFromRoot);
    }

    Component.onCompleted: syncFromRoot()

    Connections {
      target: root
      function onValueChanged() {
        if (!spinBox._syncing) {
          spinBox.syncFromRoot();
        }
      }
      function onFromChanged() {
        spinBox.scheduleSyncFromRoot();
      }
      function onToChanged() {
        spinBox.scheduleSyncFromRoot();
      }
      function onItemsChanged() {
        spinBox.scheduleSyncFromRoot();
      }
    }

    onFromChanged: scheduleSyncFromRoot()
    onToChanged: scheduleSyncFromRoot()

    onValueChanged: {
      if (spinBox._syncing) return;
      if (root.items.length > 0) {
        const mapped = itemValueFromIndex(value);
        if (root.value !== mapped) root.value = mapped;
      } else if (root.value !== value) {
        root.value = value;
      }
    }

    textFromValue: function(value) {
      if (root.items.length === 0) return value;
      const safeIndex = Math.min(Math.max(Math.floor(Number(value) || 0), 0), root.items.length - 1);
      return root.items[safeIndex];
    }

    valueFromText: function(text) {
      if (root.items.length > 0) {
        for (let i = 0; i < root.items.length; ++i) {
          if (String(root.items[i]) === String(text)) {
            return i;
          }
        }
      }
      return Math.min(Math.max(spinBox.value, 0), root.items.length > 0 ? root.items.length - 1 : spinBox.value);
    }

    background: Rectangle {
      color: "transparent"
      implicitHeight: root.height - 16
      implicitWidth: 120
    }
  }

  onClicked: {
    if (!root.editable) return;
  }
}
