//
// Created by Bryce Buchanan on 8/10/15.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include "Utilities/Util.hpp"

namespace NewRelic {

    //note replacement key must be 1 character wide
    const std::map<std::string,std::string> NewRelic::Util::Strings::_replacement_values = {
            {"\t","\\t"},
            {"\n","\\n"},
            {"\r","\\r"},
            {"\v","\\v"},
            {"\f","\\f"},
            {"\a","\\a"},
            {"\b","\\b"},
            {"\x01","^A"}, //start of heading
            {"\x02","^B"}, //start of text
            {"\x03","^C"}, //end of text
            {"\x04","^D"}, //end of transmission
            {"\x05","^E"}, //enquiry
            {"\x06","^F"}, //Acknowledge
            {"\x07","^G"}, //Ring terminal bell
            {"\x0B","^K"}, //vertical tab
            {"\x0E","^N"}, //shift out
            {"\x0F","^O"}, //shift in
            {"\x10","^P"}, //data link escape
            {"\x11","^Q"}, //device control 1
            {"\x12","^R"}, //device control 2
            {"\x13","^S"}, //device control 3
            {"\x14","^T"}, //device control 4
            {"\x15","^U"}, //Negative acknowledge
            {"\x16","^V"}, //synchronize idle
            {"\x17","^W"}, //end of transmission block
            {"\x18","^X"}, //cancel
            {"\x19","^Y"}, //end of medium
            {"\x1A","^Z"}, //substitute character
            {"\x1B","^["}, //escape
            {"\x1C","^\\"}, //file separator
            {"\x1D","^]"}, //group separator
            {"\x1E","^^"}, //record separator
            {"\x1F","^_"}, //unit separator
            {"\x7F","^?"}, //delete



    };

    //throws std::out_of_range, std::length_error
    std::string& NewRelic::Util::Strings::replaceCharactersInString(std::string& s, const std::map<std::string,std::string>& replacementMap) {
        for(auto pair = replacementMap.cbegin() ; pair != replacementMap.cend() ; pair++){
            unsigned long pos = 0;
            unsigned long search_pos = 0;
            do {
                pos = s.find(pair->first,search_pos);
                if (pos != std::string::npos) {
                    search_pos = pos + pair->second.size();
                    s.replace(pos, pair->first.size(), pair->second);
                }
            } while (pos != std::string::npos);
        }
        return s;
    }

    //throws std::out_of_range, std::length_error
    std::string& NewRelic::Util::Strings::escapeCharacterLiterals(std::string& s) {
        return replaceCharactersInString(s, _replacement_values);
    }

    //throws std::out_of_range, std::length_error
    std::string& NewRelic::Util::Strings::escapeCharacterLiterals(std::string&& s) {
        return escapeCharacterLiterals(s);
    }
}
