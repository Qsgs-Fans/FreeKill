// SPDX-License-Identifier: GPL-3.0-or-later

callbacks["UpdateAvatar"] = (jsonData) => {
  mainWindow.busy = false;
  Self.avatar = jsonData;
  toast.show("Update avatar done.");
}

callbacks["UpdatePassword"] = (jsonData) => {
  mainWindow.busy = false;
  if (jsonData === "1")
    toast.show("Update password done.");
  else
    toast.show("Old password wrong!", 5000);
}
