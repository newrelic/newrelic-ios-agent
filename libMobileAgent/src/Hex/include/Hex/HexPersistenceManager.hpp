//
// Created by Bryce Buchanan on 9/25/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#ifndef LIBMOBILEAGENT_HEXPERSISTENCEMANAGER_HPP
#define LIBMOBILEAGENT_HEXPERSISTENCEMANAGER_HPP


#include <Hex/HexStore.hpp>
#include <Hex/HexPublisher.hpp>

namespace NewRelic {
    namespace Hex {
        class HexPersistenceManager {
        public:
            HexPersistenceManager(std::shared_ptr<HexStore>& store,
                                  HexPublisher* publisher);

            ~HexPersistenceManager() = default;

            void retrieveAndPublishReports();

            void publishContext(std::shared_ptr<HexContext>const& context);

        private:
            std::shared_ptr<HexStore>& _store;
            HexPublisher* _publisher;
        };
    }
}


#endif //LIBMOBILEAGENT_HEXPERSISTENCEMANAGER_HPP
