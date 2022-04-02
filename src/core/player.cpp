#include "player.h"

Player::Player(QObject* parent)
    : QObject(parent)
    , id(0)
    , state(Player::Invalid)
    , ready(false)
{
}

Player::~Player()
{
}

int Player::getId() const
{
    return id;
}

void Player::setId(int id)
{
    this->id = id;
}

QString Player::getScreenName() const
{
    return screenName;
}

void Player::setScreenName(const QString& name)
{
    this->screenName = name;
    emit screenNameChanged();
}

QString Player::getAvatar() const
{
    return avatar;
}

void Player::setAvatar(const QString& avatar)
{
    this->avatar = avatar;
    emit avatarChanged();
}

Player::State Player::getState() const
{
    return state;
}

QString Player::getStateString() const
{
    switch (state) {
    case Online:
        return QStringLiteral("online");
    case Trust:
        return QStringLiteral("trust");
    case Robot:
        return QStringLiteral("robot");
    case Offline:
        return QStringLiteral("offline");
    default:
        return QStringLiteral("invalid");
    }
}

void Player::setState(Player::State state)
{
    this->state = state;
    emit stateChanged();
}

void Player::setStateString(const QString &state)
{
    if (state == QStringLiteral("online"))
        setState(Online);
    else if (state == QStringLiteral("trust"))
        setState(Trust);
    else if (state == QStringLiteral("robot"))
        setState(Robot);
    else if (state == QStringLiteral("offline"))
        setState(Offline);
    else
        setState(Invalid);
}

bool Player::isReady() const
{
    return ready;
}

void Player::setReady(bool ready)
{
    this->ready = ready;
    emit readyChanged();
}

