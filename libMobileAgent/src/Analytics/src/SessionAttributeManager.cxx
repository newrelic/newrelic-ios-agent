//  Copyright © 2023 New Relic. All rights reserved.

#include "Analytics/SessionAttributeManager.hpp"

namespace NewRelic {

// The copy contructor's mutex locking is a little frightening, but fear not
// this is simply a lock on both the new object, and the copying object to prevent
// any funny business while the data is moved over to the new object. 
// the unique_locks don't ever need to be "unlocked" because they are scoped to this 
// method and are automatically unlocked when they are dealloced and leave scope.
// This is a common pattern, which prevents a lot of common mistakes.

    bool SessionAttributeManager::addSessionAttribute(const char *name, const char *value) {
        try {
            auto attrib = Attribute<const char *>::createAttribute(name,
                                                                   _attributeValidator.getNameValidator(),
                                                                   value,
                                                                   _attributeValidator.getValueValidator());

            if (attrib == nullptr){
                LLOG_VERBOSE("failed to create attribute.");
                return false;
            }
             return addAttribute(attrib);

        } catch (std::invalid_argument& e) {
            LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
            return false;
        } catch (std::system_error& e) {
            LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
            return false;
        } catch (...) {
            LLOG_ERROR("Unable to add session attribute named \"%s\"",name);
            return false;
        }
    }

    bool SessionAttributeManager::incrementAttribute(const char *name, unsigned long long value) {
        //access lock
        std::unique_lock<std::recursive_mutex> attributeLock(_attributesLock,std::defer_lock);
        attributeLock.lock();

        auto attributeIterator = _sessionAttributes.find(name);
        if(attributeIterator != _sessionAttributes.end()) {
            auto attribute = attributeIterator->second->getValue();
            if(attribute->getCategory() != BaseValue::Category::NUMBER) {
                LLOG_ERROR("Unable to increment attribute \"%s\", stored value is not a number.",name);
                return false;
            }
            auto* num = dynamic_cast<Number*>(attribute.get());
            switch(num->getTag()) {
                case Number::Tag::DOUBLE:
                    return addSessionAttribute(name,num->doubleValue() + value);
                case Number::Tag::LONG:
                case Number::Tag::U_LONG:
                    return addSessionAttribute(name,num->unsignedLongLongValue() + value);
            }
        }
        return addSessionAttribute(name, value);
    }
    bool SessionAttributeManager::incrementAttribute(const char *name, unsigned long long value, bool persistent) {
        //access lock
        std::unique_lock<std::recursive_mutex> attributeLock(_attributesLock,std::defer_lock);
        attributeLock.lock(); // can throw std::system_error

        auto attributeIterator = _sessionAttributes.find(name);
        if(attributeIterator != _sessionAttributes.end()) {
            auto attribute = attributeIterator->second->getValue();
            if(attribute->getCategory() != BaseValue::Category::NUMBER) {
                LLOG_ERROR("Unable to increment attribute \"%s\", stored value is not a number.",name);
                return false;
            }
            auto* num = dynamic_cast<Number*>(attribute.get());
            switch(num->getTag()) {
                case Number::Tag::DOUBLE:
                    return addSessionAttribute(name,num->doubleValue() + value);
                case Number::Tag::LONG:
                case Number::Tag::U_LONG:
                    return addSessionAttribute(name,num->unsignedLongLongValue() + value);
            }
        }
        return addSessionAttribute(name, value, persistent);
    }

    bool SessionAttributeManager::incrementAttribute(const char *name, double value) {
        //access lock
        std::unique_lock<std::recursive_mutex> attributeLock(_attributesLock,std::defer_lock);
        attributeLock.lock();

        auto attributeIterator = _sessionAttributes.find(name);
        if(attributeIterator != _sessionAttributes.end()) {
            auto attribute = attributeIterator->second->getValue();
            if(attribute->getCategory() != BaseValue::Category::NUMBER) {
                LLOG_ERROR("Unable to increment attribute \"%s\", stored value is not a number.",name);
                return false;
            }
            auto* num = dynamic_cast<Number*>(attribute.get());
            switch(num->getTag()) {
                case Number::Tag::DOUBLE:
                    return addSessionAttribute(name,num->doubleValue() + value);
                case Number::Tag::LONG:
                case Number::Tag::U_LONG:
                    return addSessionAttribute(name,num->unsignedLongLongValue() + value);
            }
        }
            return addSessionAttribute(name, value);
    }
    bool SessionAttributeManager::incrementAttribute(const char *name, double value, bool persistent) {
        //access lock
        std::unique_lock<std::recursive_mutex> attributeLock(_attributesLock,std::defer_lock);
        attributeLock.lock(); // can throw std::system_error

        auto attributeIterator = _sessionAttributes.find(name);
        if(attributeIterator != _sessionAttributes.end()) {
            auto attribute = attributeIterator->second->getValue();
            if(attribute->getCategory() != BaseValue::Category::NUMBER) {
                LLOG_ERROR("Unable to increment attribute \"%s\", stored value is not a number.",name);
                return false;
            }
            auto* num = dynamic_cast<Number*>(attribute.get());
            switch(num->getTag()) {
                case Number::Tag::DOUBLE:
                    return addSessionAttribute(name,num->doubleValue() + value);
                case Number::Tag::LONG:
                case Number::Tag::U_LONG:
                    return addSessionAttribute(name,num->unsignedLongLongValue() + value);
            }
        }
        return addSessionAttribute(name, value, persistent);
    }

    bool SessionAttributeManager::addSessionAttribute(const char *name, double value) {
        try {
            auto attrib = Attribute<double>::createAttribute(name,
                                                            _attributeValidator.getNameValidator(),
                                                            value,
                                                            [](double){return true;});

            if (attrib == nullptr) {
                LLOG_VERBOSE("Failed to create attribute named \"%s\".",name);
                return false;
            }
            return addAttribute(attrib);

        } catch (std::invalid_argument& e) {
            LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
            return false;
        } catch (std::system_error& e) {
            LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
            return false;
        } catch (...) {
            LLOG_ERROR("Unable to add session attribute named \"%s\"",name);
            return false;
        }
    }

    bool SessionAttributeManager::addSessionAttribute(const char *name, long long value) {
        try {
            auto attrib = Attribute<long long>::createAttribute(name,
                                                                _attributeValidator.getNameValidator(),
                                                                value,
                                                                [](long long){return true;});

            if (attrib == nullptr){
                LLOG_VERBOSE("Failed to create attribute named \"%s\".",name);
                return false;
            }
            return addAttribute(attrib);

        } catch (std::invalid_argument& e) {
            LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
            return false;
        } catch (std::system_error& e) {
            LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
            return false;
        } catch (...) {
            LLOG_ERROR("Unable to add session attribute named \"%s\"",name);
            return false;
        }
    }

    bool SessionAttributeManager::addSessionAttribute(const char *name, unsigned long long value) {
        try {
            auto attrib = Attribute<unsigned long long>::createAttribute(name,
                                                                         _attributeValidator.getNameValidator(),
                                                                         value,
                                                                         [](unsigned long long){return true;});

            if (attrib == nullptr){
                LLOG_VERBOSE("Failed to create attribute named \"%s\".",name);
                return false;
            }
            return addAttribute(attrib);

        } catch (std::invalid_argument& e) {
            LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
            return false;
        } catch (std::system_error& e) {
            LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
            return false;
        } catch (...) {
            LLOG_ERROR("Unable to add session attribute named \"%s\"",name);
            return false;
        }
    }

    bool SessionAttributeManager::addSessionAttribute(const char* name, bool value) {
        try {
            auto attrib = Attribute<bool>::createAttribute(name,
                                                           _attributeValidator.getNameValidator(),
                                                           value,
                                                           [](bool){return true;});
            if(attrib == nullptr) {
                LLOG_VERBOSE("Failed to create attribute named \"%s\".",name);
                return false;
            }
            return addAttribute(attrib);
        } catch (std::invalid_argument& e) {
            LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
            return false;
        } catch (std::system_error& e) {
            LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
            return false;
        } catch (...) {
            LLOG_ERROR("Unable to add session attribute named \"%s\"",name);
            return false;
        }
    }

    bool SessionAttributeManager::addSessionAttribute(const char *name, const char *value, bool persistent) {
        try {
            auto attrib = Attribute<const char*>::createAttribute(name,
                                                                  _attributeValidator.getNameValidator(),
                                                                  value,
                                                                  _attributeValidator.getValueValidator());
            if (attrib == nullptr) {
                LLOG_VERBOSE("Failed to create attribute named \"%s\".", name);
                return false;
            }
            attrib->setPersistent(persistent);
            return addAttribute(attrib, persistent);

        } catch (std::invalid_argument& e) {
            LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
            return false;
        } catch (std::system_error& e) {
            LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
            return false;
        } catch (...) {
            LLOG_ERROR("Unable to add session attribute named \"%s\"",name);
            return false;
        }
    }

bool SessionAttributeManager::addSessionAttribute(const char *name, double value, bool persistent) {
    try {
        auto attrib = Attribute<double>::createAttribute(name,
                                                                     _attributeValidator.getNameValidator(),
                                                                     value,
                                                                     [](double){return true;}); //throws invalid_argument, std::system_error, std::out_of_range, std::length_error
        if (attrib == nullptr) {
            LLOG_VERBOSE("Failed to create attribute named \"%s\".", name);
            return false;
        }
        attrib->setPersistent(persistent);
        return addAttribute(attrib, persistent);

    } catch (std::invalid_argument& e) {
        LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
        return false;
    } catch (std::system_error& e) {
        LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
        return false;
    } catch (...) {
        LLOG_ERROR("Unable to add session attribute named \"%s\"",name);
        return false;
    }
}

bool SessionAttributeManager::addSessionAttribute(const char *name, long long value, bool persistent) {
    try {
        auto attrib = Attribute<long long>::createAttribute(name,
                                                                     _attributeValidator.getNameValidator(),
                                                                     value,
                                                                     [](long long){return true;});
        if (attrib == nullptr) {
            LLOG_VERBOSE("Failed to create attribute named \"%s\".", name);
            return false;
        }

        attrib->setPersistent(persistent);
        return addAttribute(attrib, persistent);

    } catch (std::invalid_argument& e) {
        LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
        return false;
    } catch (std::system_error& e) {
        LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
        return false;
    } catch (...) {
        LLOG_ERROR("Unable to add session attribute named \"%s\"",name);
        return false;
    }
}

bool SessionAttributeManager::addSessionAttribute(const char *name, unsigned long long value, bool persistent) {
    try {
        auto attrib = Attribute<unsigned long long>::createAttribute(name,
                                                                     _attributeValidator.getNameValidator(),
                                                                     value,
                                                                     [](unsigned long long){return true;});
        if (attrib == nullptr) {
            LLOG_VERBOSE("Failed to create attribute named \"%s\".", name);
            return false;
        }
        attrib->setPersistent(persistent);
        return addAttribute(attrib, persistent);

    } catch (std::invalid_argument& e) {
        LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
        return false;
    } catch (std::system_error& e) {
        LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
        return false;
    } catch (...) {
        LLOG_ERROR("Unable to add session attribute named \"%s\"",name);
        return false;
    }
}

    bool SessionAttributeManager::addSessionAttribute(const char* name, bool value, bool persistent) {
        try {
            auto attrib = Attribute<bool>::createAttribute(name,
                                                           _attributeValidator.getNameValidator(),
                                                           value,
                                                           [](bool) { return true; });
            if (attrib == nullptr) {
                LLOG_VERBOSE("Failed to create attribute named \"%s\".", name);
                return false;
            }
            attrib->setPersistent(persistent);
            return addAttribute(attrib, persistent);
        } catch (std::invalid_argument& e) {
            LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
            return false;
        } catch (std::system_error& e) {
            LLOG_ERROR("Unable to add session attribute named \"%s\" : %s",name,e.what());
            return false;
        } catch (...) {
            LLOG_ERROR("Unable to add session attribute named \"%s\"",name);
            return false;
        }
    }

bool SessionAttributeManager::removeSessionAttribute(const char *name) {
    //access lock
    try {
        std::unique_lock<std::recursive_mutex> attributeLock(_attributesLock,std::defer_lock);
        attributeLock.lock();

        auto attributeIterator = _sessionAttributes.find(name);
        if (attributeIterator != _sessionAttributes.end()) {
            if (attributeIterator->second->getPersistent()) {
                //remove from persistent store if applicable.
                //todo:update to PersistentAttributeStore
                _sessionAttributeStore.remove(name);

            }
            _sessionAttributes.erase(attributeIterator);
            _attributeDuplicationStore.remove(name);
            return true;
        } else {
            LLOG_WARNING("Unable to remove session attribute \"%s\"; attribute not found.",name);
            return false;
        }
    } catch (...) {
        LLOG_ERROR("unable to remove session attribute \"%s\", unknown error.");
        return false;
    }
}

bool SessionAttributeManager::clearSessionAttributes() {
        //access lock
        try {
            std::unique_lock<std::recursive_mutex> attributeLock(_attributesLock,std::defer_lock);
            attributeLock.lock();
            
            _attributeDuplicationStore.clear();
            _sessionAttributeStore.clear();
            _sessionAttributes.clear();
            return true;
        } catch (...) {
            LLOG_ERROR("Unable to clear session attributes");
            return false;
        }
    }

SessionAttributeManager::SessionAttributeManager(PersistentStore<std::string,BaseValue>& attributeStore,
                                                     PersistentStore<std::string,BaseValue>& attributeDuplicationStore,
                                                     AttributeValidator& validator)
        : _sessionAttributeStore(attributeStore), _attributeDuplicationStore(attributeDuplicationStore),_attributeValidator(validator){
    restorePersistentAttributes();
}

    bool SessionAttributeManager::restorePersistentAttributes() {
        try {
            //todo: update to use persistentAttributeStore
            auto persistentAttributeMap = _sessionAttributeStore.load();
            for (auto& iterator : persistentAttributeMap) {
                auto value = iterator.second;
                switch(value->getCategory()) {
                    case (BaseValue::Category::STRING):
                        addAttribute(Attribute<const char*>::createAttribute(iterator.first.c_str(),
                                                                             _attributeValidator.getNameValidator(),
                                                                             dynamic_cast<String*>(value.get())->getValue().c_str(),
                                                                             _attributeValidator.getValueValidator()), true);
                        break;
                    case (BaseValue::Category::NUMBER):
                        addAttribute(Attribute<double>::createAttribute(iterator.first.c_str(),
                                                                        _attributeValidator.getNameValidator(),
                                                                        dynamic_cast<Number*>(value.get())->doubleValue(),
                                                                        [](double) { return true; }), true);
                        break;
                    case (BaseValue::Category::BOOLEAN):
                        addAttribute(Attribute<bool>::createAttribute(iterator.first.c_str(),
                                                                      _attributeValidator.getNameValidator(),
                                                                      dynamic_cast<Boolean*>(value.get())->getValue(),
                                                                      [](bool) { return true; }), true);
                        break;
                }
            }
        } catch (...) {
            LLOG_VERBOSE("Unable to restore persistent attributes.");
            return false;
        }
        return true;
    }


    bool SessionAttributeManager::addAttribute(std::shared_ptr<AttributeBase> attribute, bool persistent) {

        try {
        //access lock
        std::unique_lock<std::recursive_mutex> attributeLock(_attributesLock,std::defer_lock);
        attributeLock.lock(); //can throw system_error

            if (attribute == nullptr) return false;
            std::shared_ptr<AttributeBase> insertAttribute = attribute;
            auto attributeIterator = _sessionAttributes.find(attribute->getName());
            if (attributeIterator != _sessionAttributes.end()) {
                if (!persistent && attributeIterator->second->getPersistent()) {
                    // persistence has been set to false, remove attribute from the
                    // persistent store if it exists there.
                    //todo: update to use new persistentAttributeStore
                    _sessionAttributeStore.remove(attribute->getName());
                }
                insertAttribute = attributeIterator->second;
                insertAttribute->setValue(attribute->getValue());
            } else if(_sessionAttributes.size() >= kAttributeLimit) {
                //we are going to be updating a value, so we are going to be inserting
                //validate we aren't going past the attribute limit by doing so.
                LLOG_ERROR("Unable to add attribute \"%s\", the max attribute limit (%d) is reached.",insertAttribute->getName().c_str(),kAttributeLimit);
                return false;
            }

            insertAttribute->setPersistent(persistent);
            _sessionAttributes[insertAttribute->getName()] = insertAttribute;
            _attributeDuplicationStore.store(insertAttribute->getName(),attribute->getValue());
            if (insertAttribute->getPersistent()) {
                _sessionAttributeStore.store(insertAttribute->getName(), attribute->getValue());
            }


        } catch (std::system_error& e) {
            LLOG_ERROR("Unable to add attribute \"%s\": %s",attribute->getName().c_str(),e.what());
            return false;
        } catch(...) {
            LLOG_ERROR("Unable to add attribute \"%s\"",attribute->getName().c_str());
            return false;
        }
        return true;
    }

    bool SessionAttributeManager::addNRAttribute(std::shared_ptr<AttributeBase> attribute) {
        try {
            std::lock_guard<std::mutex> attributeLock(_privateAttributesLock);
            if (attribute == nullptr) return false;
            _privateSessionAttributes[attribute->getName()] = attribute;
            _attributeDuplicationStore.store(attribute->getName(),attribute->getValue());
        } catch (...) {
            LLOG_VERBOSE("Unable to insert private attribute: %s",attribute->getName().c_str());
            return false;
        }
       return true;
    }
    bool SessionAttributeManager::addAttribute(std::shared_ptr<AttributeBase> attribute) {
        try {
            //access lock
            std::unique_lock<std::recursive_mutex> attributeLock(_attributesLock,std::defer_lock);
            attributeLock.lock();
            if (attribute == nullptr) {
                LLOG_VERBOSE("Failed to create attribute.");
                return false;
            }
            std::shared_ptr<AttributeBase> insertAttribute = attribute;
            auto attributeIterator = _sessionAttributes.find(attribute->getName());
            if (attributeIterator != _sessionAttributes.end()) {
                insertAttribute = attributeIterator->second;
                insertAttribute->setValue(attribute->getValue());
            } else if(_sessionAttributes.size() >= kAttributeLimit) {
                //we are going to be updating a value, so we are going to be inserting
                //validate we aren't going past the attribute limit by doing so.
                LLOG_ERROR("Unable to add attribute \"%s\", the max attribute limit (%d) is reached.",insertAttribute->getName().c_str(),kAttributeLimit);
                return false;
            }

            _sessionAttributes[insertAttribute->getName()] = insertAttribute;
            _attributeDuplicationStore.store(insertAttribute->getName(),attribute->getValue());
            if (insertAttribute->getPersistent()) {
                _sessionAttributeStore.store(insertAttribute->getName(), attribute->getValue());
            }

        } catch(...) {
            LLOG_ERROR("Unable to add attribute \"%s\"",attribute->getName().c_str());
            return false;
        }

        return true;
    }

    const std::map<std::string, std::shared_ptr<AttributeBase>> SessionAttributeManager::getSessionAttributes() const {
        std::unique_lock<std::recursive_mutex> attributeLock(_attributesLock,std::defer_lock);
        attributeLock.lock();
        std::map<std::string, std::shared_ptr<AttributeBase>> tempMap = std::map<std::string, std::shared_ptr<AttributeBase>>(
                _sessionAttributes);

        tempMap.insert(_privateSessionAttributes.cbegin(), _privateSessionAttributes.cend());

        return tempMap;
    }

    std::shared_ptr<NRJSON::JsonObject> SessionAttributeManager::generateJSONObject() const {
        auto tempMap = this->getSessionAttributes();
        return generateJSONObject(tempMap);
    }
    std::shared_ptr<NRJSON::JsonObject> SessionAttributeManager::generateJSONObject(std::map<std::string,std::shared_ptr<AttributeBase>>& attributes){
        NRJSON::JsonObject object = NRJSON::JsonObject();
        for (const auto& attribute : attributes) {
            auto value = attribute.second->getValue();
            if (!value) { // Null check
                LLOG_ERROR("Attribute \"%s\" has a null value.", attribute.first.c_str());
                continue;
            }
            switch (value->getCategory()) {
                case BaseValue::Category::STRING:
                    object[(std::string) attribute.first] = (dynamic_cast<String*>(value.get()))->getValue().c_str();
                    break;
                case BaseValue::Category::NUMBER:
                    object[(std::string) attribute.first] = (dynamic_cast<Number*>(value.get()))->doubleValue();
                    break;
                case BaseValue::Category::BOOLEAN:
                    object[(std::string) attribute.first] = (dynamic_cast<Boolean*>(value.get()))->getValue();
                    break;
                default:
                    LLOG_ERROR("Unknown category for attribute \"%s\".", attribute.first.c_str());
                    break;
            }
        }

        auto returnObject = std::make_shared<NRJSON::JsonObject>(object);
        return returnObject;
    }
}
