// SPDX-License-Identifier: GPL-3.0-or-later

// Make the base classes look like "complete"
class QObject {};
class QThread {
public:
  static void msleep(long msec);
};

template <class T>
class QList {
public:
  QList();
  ~QList();
  int length() const;
  void append(const T &elem);
  void prepend(const T &elem);
  bool isEmpty() const;
  bool contains(const T &value) const;
  T first() const;
  T last() const;
  void removeAt(int i);
  int removeAll(const T &value);
  bool removeOne(const T &value);
  QList<T> mid(int pos, int length = -1) const;
  int indexOf(const T &value, int from = 0);
  void replace(int i, const T &value);
  void swapItemsAt(int i, int j);
};

%extend QList {
  T at(int i) const
  {
    return $self->value(i);
  }
}

%template(SPlayerList) QList<ServerPlayer *>;
%template(PlayerList)  QList<const Player *>;
%template(IntList) QList<int>;
%template(BoolList) QList<bool>;

%native(GetMicroSecond) int GetMicroSecond(lua_State *L);
%{
#include <sys/time.h>
static int GetMicroSecond(lua_State *L) {
  struct timeval tv;
  gettimeofday(&tv, nullptr);
  long long microsecond = tv.tv_sec * 1000000 + tv.tv_usec;
  lua_pushnumber(L, microsecond);
  return 1;
}
%}

void qDebug(const char *msg, ...);
void qInfo(const char *msg, ...);
void qWarning(const char *msg, ...);
void qCritical(const char *msg, ...);
