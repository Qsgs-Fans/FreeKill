// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _SHELL_H
#define _SHELL_H

class Shell: public QThread {
  Q_OBJECT
public:
  Shell();

  void handleLine(char *);

protected:
  virtual void run();

private:
  QHash<QString, void (Shell::*)(QStringList &)> handler_map;
  void helpCommand(QStringList &);
  void quitCommand(QStringList &);
  void lspCommand(QStringList &);
  void lsrCommand(QStringList &);
  void installCommand(QStringList &);
  void removeCommand(QStringList &);
  void upgradeCommand(QStringList &);
  void lspkgCommand(QStringList &);
  void enableCommand(QStringList &);
  void disableCommand(QStringList &);
  void kickCommand(QStringList &);
  void msgCommand(QStringList &);
  void banCommand(QStringList &);
  void banipCommand(QStringList &);
  void banUuidCommand(QStringList &);
  void unbanCommand(QStringList &);
  void unbanipCommand(QStringList &);
  void unbanUuidCommand(QStringList &);
  void reloadConfCommand(QStringList &);
  void resetPasswordCommand(QStringList &);

#ifdef FK_USE_READLINE
private:
  QString syntaxHighlight(char *);
public:
  void redisplay();
  void moveCursorToStart();
  void clearLine();
  bool lineDone() const;
  char *generateCommand(const char *, int);

#endif
};

extern Shell *ShellInstance;

#endif
