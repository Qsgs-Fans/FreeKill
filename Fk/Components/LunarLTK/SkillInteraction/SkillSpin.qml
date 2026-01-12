// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls

import Fk
import Fk.Components.LunarLTK

SpinBox {
  background: Rectangle { color: "#88EEEEEE" }
  property int answer: value
  property string skill
  // from, to

  onValueChanged: {
    Ltk.updateRequestUI("Interaction", "1", "update", value);
  }
}
