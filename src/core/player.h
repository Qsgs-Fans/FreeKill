#ifndef _PLAYER_H
#define _PLAYER_H

#include <QObject>

// Common part of ServerPlayer and ClientPlayer
// dont initialize it directly
class Player : public QObject {
    Q_OBJECT

public:
    enum State{
        Invalid,
        Online,
        Trust,
        Offline
    };

    explicit Player(QObject *parent = nullptr);
    ~Player();

    uint getId() const;

    QString getScreenName() const;
    void setScreenName(const QString &name);

    QString getAvatar() const;
    void setAvatar(const QString &avatar);

    State getState() const;
    QString getStateString() const;
    void setState(State state);
    void setStateString(const QString &state);

    bool isReady() const;
    void setReady(bool ready);

signals:
    void screenNameChanged();
    void avatarChanged();
    void stateChanged();
    void readyChanged();

private:
    uint id;
    QString screenName;
    QString avatar;
    State state;
    bool ready;
};

#endif // _PLAYER_H
