#ifndef _PARSER_H
#define _PARSER_H

#include "fkparse.h"

class Parser {
public:
  Parser();
  ~Parser();
  int parse(const QString &filename);
  static void parseFkp();

private:
  fkp_parser *parser;
  QHash<QString, QString> generals;
  QHash<QString, QString> skills;
  QHash<QString, QString> marks;

  void readHashFromParser();
};

#endif
