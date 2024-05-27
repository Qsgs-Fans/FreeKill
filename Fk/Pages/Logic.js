// SPDX-License-Identifier: GPL-3.0-or-later

callbacks["UpdateAvatar"] = (jsonData) => {
  mainWindow.busy = false;
  Self.avatar = jsonData;
  toast.show(luatr("Update avatar done."));
}

callbacks["UpdatePassword"] = (jsonData) => {
  mainWindow.busy = false;
  if (jsonData === "1")
    toast.show(luatr("Update password done."));
  else
    toast.show(luatr("Old password wrong!"), 5000);
}
