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

    unsigned int getId() const;
    void setId(unsigned int id);

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
    void setSocket(ClientSocket *socket);

    Server *getServer() const;
    Room *getRoom() const;
    void setRoom(Room *room);

    void speak(const QString &message);

    void doRequest(const QString &command,
                   const QString &json_data, int timeout = -1);
    void doReply(const QString &command, const QString &json_data);
    void doNotify(const QString &command, const QString &json_data);

    void prepareForRequest(const QString &command,
                           const QVariant &data = QVariant());
};
