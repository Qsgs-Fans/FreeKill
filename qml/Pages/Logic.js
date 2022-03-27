callbacks["UpdateAvatar"] = function(jsonData) {
    mainWindow.busy = false;
    self.avatar = avatarName.text;
    toast.show("Update avatar done.");
}

callbacks["UpdatePassword"] = function(jsonData) {
    mainWindow.busy = false;
    if (jsonData === "1")
        toast.show("Update password done.");
    else
        toast.show("Old password wrong!", 5000);
}
