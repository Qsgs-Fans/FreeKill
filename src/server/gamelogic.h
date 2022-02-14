#ifndef _GAMELOGIC_H
#define _GAMELOGIC_H

#include <QThread>
class Room;

// Just like the class 'RoomThread' in QSanguosha
class GameLogic : public QThread {
    Q_OBJECT
public:
    explicit GameLogic(Room *room);

protected:
    virtual void run();
};

#endif // _GAMELOGIC_H
