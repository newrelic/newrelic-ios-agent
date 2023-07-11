//  Copyright © 2023 New Relic. All rights reserved.

#ifndef JSON_HH
#define JSON_HH

#include <JSON/json_st.hh> // JSON syntax tree
#include <JSON/json.tab.hh> // parser
  
NRJSON::JsonValue parse_file(const char* filename);
NRJSON::JsonValue parse_string(const std::string& s);

#endif
