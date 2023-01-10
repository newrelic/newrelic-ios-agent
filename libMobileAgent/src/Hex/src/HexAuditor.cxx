//
// Created by Bryce Buchanan on 7/11/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include "Hex/HexAuditor.hpp"
#include <Utilities/libLogger.hpp>

using namespace NewRelic::Hex;
using namespace com::newrelic::mobile;

void HexAuditor::audit(uint8_t* buf) {
    ss.str(std::string()); // clear
    auto agentDataBundle = com::newrelic::mobile::fbs::GetAgentDataBundle(buf);
    int indentations = 0;
    printStringWithIndentation("AgentDataBundle:\n[", indentations);
    indentations++;
    for (auto it = agentDataBundle->agentData()->begin(); it != agentDataBundle->agentData()->end(); it++) {
        printStringWithIndentation("{", indentations);
        printApplicationinfo(it->applicationInfo(), indentations);
        printStringAttributes(it->stringAttributes(), indentations);
        printLongAttributes(it->longAttributes(), indentations);
        printDoubleAttributes(it->doubleAttributes(), indentations);
        printBoolAttributes(it->boolAttributes(), indentations);
        printHandledExceptions(it->handledExceptions(), indentations);
        printStringWithIndentation("}", indentations);
    }
    indentations--;
    printStringWithIndentation("]", indentations);
    LLOG_AUDIT("%s", ss.str().c_str());
}


void HexAuditor::printStringWithIndentation(const char* string,
                                            int indentation) {
    for (int i = 0; i < indentation; i++) {
        ss << "\t";
    }
    ss << string << std::endl;
}

void
HexAuditor::printStringAttributes(const flatbuffers::Vector<flatbuffers::Offset<fbs::StringSessionAttribute>>* attributes,
                                  int indent) {
    printStringWithIndentation("stringAttributes : {", indent);
    indent++;
    int count = attributes->Length();
    for (int i = 0; i < count; i++) {
        auto item = attributes->Get(i);
        std::stringstream ss;

        ss << "\"" << item->name()->c_str() << "\" : \"" << item->value()->c_str() << "\",";
        printStringWithIndentation(ss.str().c_str(), indent);
    }
    indent--;
    printStringWithIndentation("}", indent);
}

void
HexAuditor::printLongAttributes(const flatbuffers::Vector<flatbuffers::Offset<fbs::LongSessionAttribute>>* attributes,
                                int indent) {
    printStringWithIndentation("longAttributes : {", indent);
    indent++;
    int count = attributes->Length();
    for (int i = 0; i < count; i++) {
        auto item = attributes->Get(i);
        std::stringstream ss;
        ss << "\"" << item->name()->c_str() << "\" :  " << item->value() << ",";
        printStringWithIndentation(ss.str().c_str(), indent);
    }
    indent--;
    printStringWithIndentation("}", indent);
}

void
HexAuditor::printDoubleAttributes(const flatbuffers::Vector<flatbuffers::Offset<fbs::DoubleSessionAttribute>>* attributes,
                                  int indent) {
    printStringWithIndentation("doubleAttributes : {", indent);
    indent++;
    int count = attributes->Length();
    for (int i = 0; i < count; i++) {
        auto item = attributes->Get(i);
        std::stringstream ss;
        ss << "\"" << item->name()->c_str() << "\" : " << item->value() << ",";
        printStringWithIndentation(ss.str().c_str(), indent);
    }
    indent--;
    printStringWithIndentation("},", indent);
}

void
HexAuditor::printBoolAttributes(const flatbuffers::Vector<flatbuffers::Offset<fbs::BoolSessionAttribute>>* attributes,
                                int indent) {
    printStringWithIndentation("boolAttributes : {", indent);
    indent++;
    int count = attributes->Length();
    for (int i = 0; i < count; i++) {
        auto item = attributes->Get(i);
        std::stringstream ss;
        ss << "\"" << item->name()->c_str() << "\" : " << (item->value() ? "true" : "false") << ",";
        printStringWithIndentation(ss.str().c_str(), indent);
    }
    indent--;
    printStringWithIndentation("}", indent);
}

void HexAuditor::printApplicationinfo(const fbs::ApplicationInfo* info,
                                      int indent) {
    indent++;
    printStringWithIndentation("applicationInfo : {", indent);

    indent++;
    {
        printStringWithIndentation("\"applicationLicense\" : {", indent);
        printApplicationLicense(info->applicationLicense(), indent);
        printStringWithIndentation("}", indent);
    }

    {
        std::stringstream ss;
        ss << "\"Platform\" : \"" << fbs::EnumNamePlatform(info->platform()) << "\",";
        printStringWithIndentation(ss.str().c_str(), indent);
    }
    indent--;
    printStringWithIndentation("}", indent);
}

void HexAuditor::printApplicationLicense(const fbs::ApplicationLicense* license,
                                         int indent) {
    indent++;
    {
        std::stringstream ss;
        ss << "\"licenseKey\" : \"" << license->licenseKey()->c_str() << "\",";
        printStringWithIndentation(ss.str().c_str(), indent);
    }
}


void
HexAuditor::printHandledExceptions(const flatbuffers::Vector<flatbuffers::Offset<com::newrelic::mobile::fbs::hex::HandledException> >* exceptions,
                                   int indent) {
    printStringWithIndentation("Exceptions : [", indent);
    indent++;
    for (int i = 0; i < exceptions->Length(); i++) {
        printHandledException(exceptions->Get(i), indent);
    }
    printStringWithIndentation("],", indent);
}

void HexAuditor::printHandledException(const fbs::hex::HandledException* hex,
                                       int indent) {

    printStringWithIndentation("handledException : {", indent);
    indent++;
    {
        std::stringstream ss;
        ss << "\"appUuidLow\" : \",";
        ss << "0x" << std::hex << hex->appUuidLow() << "\",";
        printStringWithIndentation(ss.str().c_str(), indent);
    }
    {
        std::stringstream ss;
        ss << "\"appUuidHigh\" : \",";
        ss << "0x" << "0x" << std::hex << hex->appUuidHigh() << "\",";
        printStringWithIndentation(ss.str().c_str(), indent);
    }
    {
        std::stringstream ss;
        ss << "\"sessionId\" : \",";
        ss << hex->sessionId()->c_str() << "\",";
        printStringWithIndentation(ss.str().c_str(), indent);
    }
    {
        std::stringstream ss;
        ss << "\"timestampMs\" : ";
        ss << hex->timestampMs();
        printStringWithIndentation(ss.str().c_str(), indent);
    }
    {
        std::stringstream ss;
        ss << "\"message\" : \"";
        ss << hex->message()->c_str() << "\",";
        printStringWithIndentation(ss.str().c_str(), indent);
    }
    {
        std::stringstream ss;
        ss << "\"name\" : \"";
        ss << hex->name()->c_str() << "\",";
        printStringWithIndentation(ss.str().c_str(), indent);
    }

    printThreads(hex->threads(), indent);


    printStringWithIndentation("libraries : [", indent);
    printLibraries(hex->libraries(), indent);
    printStringWithIndentation("],", indent);

    indent--;
    printStringWithIndentation("},", indent);
}

void HexAuditor::printThreads(const flatbuffers::Vector<flatbuffers::Offset<fbs::hex::Thread>>* threads,
                              int indent) {
    printStringWithIndentation("threads : [", indent);
    indent++;
    {
        for (int i = 0; i < threads->Length(); i++) {
            printStringWithIndentation("[", indent);
            printThread(threads->Get(i)->frames(), indent);
            printStringWithIndentation("],", indent);
        }
    }
    indent--;
    printStringWithIndentation("],", indent);
}

void HexAuditor::printThread(const flatbuffers::Vector<flatbuffers::Offset<fbs::hex::Frame>>* frames,
                             int indent) {
    indent++;
    for (int i = 0; i < frames->Length(); i++) {
        {
            std::stringstream ss;
            ss << frames->Get(i)->value()->c_str();
            printStringWithIndentation(ss.str().c_str(), indent);
        }
        {
            std::stringstream ss;
            ss << "0x" << std::hex << frames->Get(i)->address();
            printStringWithIndentation(ss.str().c_str(), indent);

        }
    }
}

void HexAuditor::printLibraries(const flatbuffers::Vector<flatbuffers::Offset<fbs::ios::Library>>* libraries,
                                int indent) {
    indent++;

    for (int i = 0; i < libraries->Length(); i++) {
        printStringWithIndentation("{", indent);
        indent++;
        auto it = libraries->Get(i);
        {
            std::stringstream ss;
            ss << "\"uuidLow\" : " << "0x" << std::hex << it->uuidLow() << ",";
            printStringWithIndentation(ss.str().c_str(), indent);
        }
        {
            std::stringstream ss;
            ss << "\"uuidHigh\" : " << "0x" << std::hex << it->uuidHigh() << ",";
            printStringWithIndentation(ss.str().c_str(), indent);
        }
        {
            std::stringstream ss;
            ss << "\"address\" : " << "0x" << std::hex << it->address() << ",";
            printStringWithIndentation(ss.str().c_str(), indent);
        }
        {
            std::stringstream ss;
            ss << "\"userLibrary\" : " << (it->userLibrary() ? "true" : "false") << ",";
            printStringWithIndentation(ss.str().c_str(), indent);
        }
        {
            std::stringstream ss;
            ss << "\"arch\" : " << (fbs::ios::EnumNameArch(it->arch())) << ",";
            printStringWithIndentation(ss.str().c_str(), indent);
        }
        indent--;
        printStringWithIndentation("},", indent);
    }

}
