// SPDX-License-Identifier: GPL-3.0-or-later

// Make the base classes look like "complete"

%nodefaultctor QObject;
%nodefaultdtor QObject;
class QObject {};

%nodefaultctor QThread;
%nodefaultdtor QThread;
class QThread {};

%nodefaultctor QList;
%nodefaultdtor QList;
template <class T>
class QList {
public:
  int length() const;
  T at(int i) const;
};

%template(SPlayerList) QList<ServerPlayer *>;
%template(IntList) QList<int>;

%native(GetMicroSecond) int GetMicroSecond(lua_State *L);
%{
#include <sys/time.h>
static int GetMicroSecond(lua_State *L) {
  struct timeval tv;
  gettimeofday(&tv, nullptr);
  long long microsecond = (long long)tv.tv_sec * 1000000 + tv.tv_usec;
  lua_pushnumber(L, microsecond);
  return 1;
}
%}

void qDebug(const char *msg, ...);
void qInfo(const char *msg, ...);
void qWarning(const char *msg, ...);
void qCritical(const char *msg, ...);

class QJsonDocument {
public:
  enum JsonFormat {
    Indented,
    Compact,
  };
  static QJsonDocument fromJson(const QByteArray &json);
  static QJsonDocument fromVariant(const QVariant &variant);
  QByteArray toJson(QJsonDocument::JsonFormat format = 1) const;
  QVariant toVariant() const;
};
