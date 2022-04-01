function arrangePhotos() {
    /* Layout of photos:
     * +---------------+
     * |   6 5 4 3 2   |
     * | 7           1 |
     * |   dashboard   |
     * +---------------+
     */

    const photoWidth = 175;
    const roomAreaPadding = 10;
    let verticalPadding = Math.max(10, roomArea.width * 0.01);
    let horizontalSpacing = Math.max(30, roomArea.height * 0.1);
    let verticalSpacing = (roomArea.width - photoWidth * 7 - verticalPadding * 2) / 6;

    // Position 1-7
    const regions = [
        { x: verticalPadding + (photoWidth + verticalSpacing) * 6, y: roomAreaPadding + horizontalSpacing * 2 },
        { x: verticalPadding + (photoWidth + verticalSpacing) * 5, y: roomAreaPadding + horizontalSpacing },
        { x: verticalPadding + (photoWidth + verticalSpacing) * 4, y: roomAreaPadding },
        { x: verticalPadding + (photoWidth + verticalSpacing) * 3, y: roomAreaPadding },
        { x: verticalPadding + (photoWidth + verticalSpacing) * 2, y: roomAreaPadding },
        { x: verticalPadding + photoWidth + verticalSpacing, y: roomAreaPadding + horizontalSpacing },
        { x: verticalPadding, y: roomAreaPadding + horizontalSpacing * 2 },
    ];

    const regularSeatIndex = [
        [4],
        [3, 5],
        [1, 4, 7],
        [1, 3, 5, 7],
        [1, 3, 4, 5, 7],
        [1, 2, 3, 5, 6, 7],
        [1, 2, 3, 4, 5, 6, 7],
    ];
    let seatIndex = regularSeatIndex[playerNum - 2];

    let item, region, i;

    for (i = 0; i < playerNum - 1; i++) {
        item = photos.itemAt(i);
        if (!item)
            continue;

        region = regions[seatIndex[photoModel.get(i).index] - 1];
        item.x = region.x;
        item.y = region.y;
    }
}

callbacks["AddPlayer"] = function(jsonData) {
    // jsonData: int id, string screenName, string avatar
    for (let i = 0; i < photoModel.count; i++) {
        let item = photoModel.get(i);
        if (item.id === -1) {
            let data = JSON.parse(jsonData);
            let uid = data[0];
            let name = data[1];
            let avatar = data[2];
            item.id = uid;
            item.screenName = name;
            item.general = avatar;
            return;
        }
    }
}

callbacks["RemovePlayer"] = function(jsonData) {
    // jsonData: int uid
    let uid = JSON.parse(jsonData)[0];
    for (let i = 0; i < photoModel.count; i++) {
        let item = photoModel.get(i);
        if (item.id === uid) {
            item.id = -1;
            item.screenName = "";
            item.general = "";
            return;
        }
    }
}

callbacks["RoomOwner"] = function(jsonData) {
    // jsonData: int uid of the owner
    let uid = JSON.parse(jsonData)[0];

    if (dashboardModel.id === uid) {
        dashboardModel.isOwner = true;
        roomScene.dashboardModelChanged();
        return;
    }

    for (let i = 0; i < photoModel.count; i++) {
        let item = photoModel.get(i);
        if (item.id === uid) {
            item.isOwner = true;
            return;
        }
    }
}

callbacks["PropertyUpdate"] = function(jsonData) {
    // jsonData: int id, string property_name, value
    let data = JSON.parse(jsonData);
    let uid = data[0];
    let property_name = data[1];
    let value = data[2];

    if (Self.id === uid) {
        dashboardModel[property_name] = value;
        roomScene.dashboardModelChanged();
        return;
    }

    for (let i = 0; i < photoModel.count; i++) {
        let item = photoModel.get(i);
        if (item.id === uid) {
            item[property_name] = value;
            return;
        }
    }
}

callbacks["ArrangeSeats"] = function(jsonData) {
    // jsonData: seat order
    let order = JSON.parse(jsonData);
    roomScene.isStarted = true;

    for (let i = 0; i < photoModel.count; i++) {
        let item = photoModel.get(i);
        item.seatNumber = order.indexOf(item.id) + 1;
    }

    dashboardModel.seatNumber = order.indexOf(Self.id) + 1;
    roomScene.dashboardModelChanged();
    
    // make Self to the first of list, then reorder photomodel
    let selfIndex = order.indexOf(Self.id);
    let after = order.splice(selfIndex);
    after.push(...order);
    let photoOrder = after.slice(1);

    for (let i = 0; i < photoModel.count; i++) {
        let item = photoModel.get(i);
        item.index = photoOrder.indexOf(item.id);
    }
    
    arrangePhotos();
}

function cancelAllFocus() {
    let item;
    for (let i = 0; i < playerNum - 1; i++) {
        item = photos.itemAt(i);
        item.progressBar.visible = false;
        item.progressTip = "";
    }
}

callbacks["MoveFocus"] = function(jsonData) {
    // jsonData: int[] focuses, string command
    cancelAllFocus();
    let data = JSON.parse(jsonData);
    let focuses = data[0];
    let command = data[1];
    
    let item, model;
    for (let i = 0; i < playerNum - 1; i++) {
        model = photoModel.get(i);
        if (focuses.indexOf(model.id) != -1) {
            item = photos.itemAt(i);
            item.progressBar.visible = true;
            item.progressTip = command + " thinking...";
        }
    }
}

callbacks["AskForGeneral"] = function(jsonData) {
    // jsonData: string[] Generals
    // TODO: choose multiple generals
    let data = JSON.parse(jsonData);
    roomScene.popupBox.source = "RoomElement/ChooseGeneralBox.qml";
    let box = roomScene.popupBox.item;
    box.choiceNum = 1;
    box.accepted.connect(() => {
        ClientInstance.replyToServer("AskForGeneral", JSON.stringify([box.choices[0]]));
    });
    for (let i = 0; i < data.length; i++)
        box.generalList.append({ "name": data[i] });
    box.updatePosition();
}

callbacks["AskForSkillInvoke"] = function(jsonData) {
    // jsonData: string name
}
