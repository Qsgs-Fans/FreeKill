%nodefaultctor Player;
%nodefaultdtor Player;
class Player : public QObject {
public:
    enum State{
        Invalid,
        Online,
        Trust,
        Offline
    };

    int getId() const;
    void setId(int id);

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
};

%nodefaultctor ClientPlayer;
%nodefaultdtor ClientPlayer;
class ClientPlayer : public Player {
public:
};

extern ClientPlayer *Self;

%nodefaultctor ServerPlayer;
%nodefaultdtor ServerPlayer;
class ServerPlayer : public Player {
public:
    Server *getServer() const;
    Room *getRoom() const;
    void setRoom(Room *room);

    void speak(const QString &message);

    void doRequest(const QString &command,
                   const QString &json_data, int timeout);
    QString waitForReply();
    QString waitForReply(int timeout);
    void doNotify(const QString &command, const QString &json_data);

    void prepareForRequest(const QString &command, const QString &data);
};
