// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls

SpinBox {
  background: Rectangle { color: "#88EEEEEE" }
  property int answer: value
  property string skill
  // from, to

  onValueChanged: {
    lcall("UpdateRequestUI", "Interaction", "1", "update", value);
  }
}
