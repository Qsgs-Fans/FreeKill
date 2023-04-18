// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _SHELL_H
#define _SHELL_H

class Shell: public QThread {
  Q_OBJECT
public:
  Shell();

  enum Color {
    Black,
    Red,
    Green,
    Yellow,
    Blue,
    Magenta,
    Cyan,
  };
  enum TextType {
    NoType,
    Bold,
    UnderLine
  };

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
};

#endif
