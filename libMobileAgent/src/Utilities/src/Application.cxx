
#include "Utilities/Application.hpp"

namespace NewRelic {

Application* Application::__instance = nullptr;

Application::Application() : _context(ApplicationContext("","")) {}

Application& Application::getInstance() {
    if (__instance == nullptr) {
        __instance = new Application();
    }
    return *Application::__instance;
}

const ApplicationContext& Application::getContext() const {
    return _context;
}

bool Application::isValid() {
    return _context.getApplicationId().length() > 0 && _context.getAccountId().length() > 0;
}

void Application::setContext(ApplicationContext&& context) {
    _context = std::move(context);
}

}
