//  Copyright © 2023 New Relic. All rights reserved.

#include <JSON/json_st.hh>
#include <stdexcept>
#include <string>
#include <iomanip>
#include <Utilities/Util.hpp>
using namespace std;
using namespace NRJSON;

JsonValue::JsonValue() : type_t(NIL) { }

JsonValue::JsonValue(const long long int i) : int_v(i), type_t(INT) { }

JsonValue::JsonValue(const long int i) : int_v(static_cast<long long int>(i)), type_t(INT) { }

JsonValue::JsonValue(const int i) : int_v(static_cast<int>(i)), type_t(INT) { }

JsonValue::JsonValue(const long double f) : float_v(f), type_t(FLOAT) { }

JsonValue::JsonValue(const double f) : float_v(static_cast<long double>(f)), type_t(FLOAT) { }

JsonValue::JsonValue(const bool b) : bool_v(b), type_t(BOOL) { }

JsonValue::JsonValue(const char* s) : string_v(s), type_t(STRING) { }

JsonValue::JsonValue(const string& s) : string_v(s), type_t(STRING) { }

JsonValue::JsonValue(const JsonObject & o) : object_v(o), type_t(OBJECT) { }

JsonValue::JsonValue(const JsonArray & o) : array_v(o), type_t(ARRAY) { }

JsonValue::JsonValue(string&& s) : string_v(std::move(s)), type_t(STRING) { }

JsonValue::JsonValue(JsonObject&& o) : object_v(std::move(o)), type_t(OBJECT) { }

JsonValue::JsonValue(JsonArray&& o) : array_v(std::move(o)), type_t(ARRAY) { }

JsonValue::JsonValue(const JsonValue & v)
{ 
    switch(v.type())
    {
        /** Base types */
        case INT:
            int_v = v.int_v;
            type_t = INT;
            break;
        
        case FLOAT:
            float_v = v.float_v;
            type_t = FLOAT;
            break;
        
        case BOOL:
            bool_v = v.bool_v;
            type_t = BOOL;
            break;
        
        case NIL:
            type_t = NIL;
            break;
        
        case STRING:
            string_v = v.string_v;
            type_t = STRING;
            break;
        
        /** Compound types */
            case ARRAY:
            array_v = v.array_v;
            type_t = ARRAY;
            break;
        
        case OBJECT:
            object_v = v.object_v;
            type_t = OBJECT;
            break;
        
    }
}

JsonValue::JsonValue(JsonValue&& v)
{ 
    switch(v.type())
    {
        /** Base types */
        case INT:
            int_v = std::move(v.int_v);
            type_t = INT;
            break;
        
        case FLOAT:
            float_v = std::move(v.float_v);
            type_t = FLOAT;
            break;
        
        case BOOL:
            bool_v = std::move(v.bool_v);
            type_t = BOOL;
            break;
        
        case NIL:
            type_t = NIL;
            break;
        
        case STRING:
            string_v = std::move(v.string_v);
            type_t = STRING;
            break;
        
        /** Compound types */
            case ARRAY:
            array_v = std::move(v.array_v);
            type_t = ARRAY;
            break;
        
        case OBJECT:
            object_v = std::move(v.object_v);
            type_t = OBJECT;
            break;
        
    }
}

JsonValue &JsonValue::operator=(const JsonValue & v)
{
    switch(v.type())
    {
        /** Base types */
        case INT:
            int_v = v.int_v;
            type_t = INT;
            break;
        
        case FLOAT:
            float_v = v.float_v;
            type_t = FLOAT;
            break;
        
        case BOOL:
            bool_v = v.bool_v;
            type_t = BOOL;
            break;
        
        case NIL:
            type_t = NIL;
            break;
        
        case STRING:
            string_v = v.string_v;
            type_t = STRING;
            break;
        
        /** Compound types */
            case ARRAY:
            array_v = v.array_v;
            type_t = ARRAY;
            break;
        
        case OBJECT:
            object_v = v.object_v;
            type_t = OBJECT;
            break;
        
    }
    
    return *this;

}

JsonValue &JsonValue::operator=(JsonValue&& v)
{
    switch(v.type())
    {
        /** Base types */
        case INT:
            int_v = std::move(v.int_v);
            type_t = INT;
            break;
        
        case FLOAT:
            float_v = std::move(v.float_v);
            type_t = FLOAT;
            break;
        
        case BOOL:
            bool_v = std::move(v.bool_v);
            type_t = BOOL;
            break;
        
        case NIL:
            type_t = NIL;
            break;
        
        case STRING:
            string_v = std::move(v.string_v);
            type_t = STRING;
            break;
        
        /** Compound types */
            case ARRAY:
            array_v = std::move(v.array_v);
            type_t = ARRAY;
            break;
        
        case OBJECT:
            object_v = std::move(v.object_v);
            type_t = OBJECT;
            break;
        
    }
    
    return *this;

}

JsonValue &JsonValue::operator[] (const string& key)
{
    if (type() != OBJECT)
        throw std::logic_error("Value not an object");
    return object_v[key];
}

const JsonValue &JsonValue::operator[] (const string& key) const
{
    if (type() != OBJECT)
        throw std::logic_error("Value not an object");
    return object_v[key];
}

JsonValue &JsonValue::operator[] (size_t i)
{
    if (type() != ARRAY)
        throw std::logic_error("Value not an array");
    return array_v[i];
}

const JsonValue &JsonValue::operator[] (size_t i) const
{
    if (type() != ARRAY)
        throw std::logic_error("Value not an array");
    return array_v[i];
}


JsonObject::JsonObject() { }

JsonObject::~JsonObject() { }

JsonObject::JsonObject(const JsonObject & o) : _object(o._object) { }

JsonObject::JsonObject(JsonObject&& o) : _object(std::move(o._object)) { }

JsonObject &JsonObject::operator=(const JsonObject & o)
{
    _object = o._object;
    return *this;
}

JsonObject &JsonObject::operator=(JsonObject&& o)
{
    _object = std::move(o._object);
    return *this;
}

JsonValue &JsonObject::operator[] (const string& key)
{
    return _object[key];
}

const JsonValue &JsonObject::operator[] (const string& key) const
{
    return _object.at(key);
}

pair<map<string, JsonValue>::iterator, bool> JsonObject::insert(const pair<string, JsonValue>& v)
{
    return _object.insert(v);
}

map<string, JsonValue>::const_iterator JsonObject::begin() const
{
    return _object.begin();
}

map<string, JsonValue>::const_iterator JsonObject::end() const
{
    return _object.end();
}

map<string, JsonValue>::iterator JsonObject::begin()
{
    return _object.begin();
}

map<string, JsonValue>::iterator JsonObject::end()
{
    return _object.end();
}

size_t JsonObject::size() const
{
    return _object.size();
}

JsonArray::JsonArray() { }

JsonArray::~JsonArray() { }

JsonArray::JsonArray(const JsonArray & a) : _array(a._array) { }

JsonArray::JsonArray(JsonArray&& a) : _array(std::move(a._array)) { }

JsonArray &JsonArray::operator=(const JsonArray & a)
{
    _array = a._array;
    return *this;
}

JsonArray &JsonArray::operator=(JsonArray&& a)
{
    _array = std::move(a._array);
    return *this;
}


JsonValue &JsonArray::operator[] (size_t i)
{
    return _array.at(i);
}

const JsonValue &JsonArray::operator[] (size_t i) const
{
    return _array.at(i);
}

vector<JsonValue>::const_iterator JsonArray::begin() const
{
    return _array.begin();
}

vector<JsonValue>::const_iterator JsonArray::end() const
{
    return _array.end();
}

vector<JsonValue>::iterator JsonArray::begin()
{
    return _array.begin();
}

vector<JsonValue>::iterator JsonArray::end()
{
    return _array.end();
}

size_t JsonArray::size() const
{
    return _array.size();
}

void JsonArray::push_back(const JsonValue & v)
{
    _array.push_back(v);
}


string JsonObject::escapeJsonControlCharacters(std::string string) {
    //the order of these replacements are important.
    //first replace all backslashes with an escaped backslash.
    //then escape the quote. If we reversed this there would be too many escaped backslashes.
    std::string& str = NewRelic::Util::Strings::replaceCharactersInString(string,{{"\\","\\\\"},});
    return NewRelic::Util::Strings::replaceCharactersInString(str,{{"\"","\\\""},});
}
ostream& operator<<(ostream& os, const JsonValue & v)
{    
    switch(v.type())
    {
        /** Base types */
        case INT:
            os << (long long int)v;
            break;
        
        case FLOAT:
            os << std::setprecision(15) << (long double)v; //set precision for timestamps (in milliseconds) if precision isn't set high enough, timestamps will get truncated into scinotif.
            //setting precision here will allow number upto 15 points of percision, however, it does not force that level of precision. You will not see an integer with 15 zeros in the decimal order.
            break;
        
        case BOOL:
            os << ((bool)v ? "true" : "false");
            break;
        
        case NIL:
            os << "null";
            break;
        
        case STRING:
            os << '"' << JsonObject::escapeJsonControlCharacters((string)v) << '"';
            break;
        
        /** Compound types */
        case ARRAY:
            os << (JsonArray)v;
            break;
        
        case OBJECT:
            os << (JsonObject)v;
            break;
        
    }
    return os;
}


ostream& operator<<(ostream& os, const JsonObject & o)
{    
    os << "{" << endl;
    for (auto e = o.begin(); e != o.end();)
    {
        //e->first is a string, not a JsonValue so it wont be caught by the JsonValue operator<< above.
        os << '"' << JsonObject::escapeJsonControlCharacters(e->first) << '"' << ": " ;
        os << e->second;
        if (++e != o.end())
            os << ",";
        os << endl;
    }    
    os << "}";
    
    return os;
}

ostream& operator<<(ostream& os, const JsonArray & a)
{
    os << "[" << endl;
    for (auto e = a.begin(); e != a.end();)
    {
        os << (*e);
        if (++e != a.end())
            os << ",";
        os << endl;
    }    
    os << "]";
    
    return os;
}
