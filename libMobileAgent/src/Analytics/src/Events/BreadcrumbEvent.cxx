#include <Analytics/Constants.hpp>
#include "BreadcrumbEvent.hpp"

NewRelic::BreadcrumbEvent::BreadcrumbEvent(unsigned long long timestamp_epoch_millis, double session_elapsed_time_sec,
                                           AttributeValidator& attributeValidator)
: CustomEvent(std::make_shared<std::string>(__kNRMA_RET_mobileBreadcrumb),
              timestamp_epoch_millis,
              session_elapsed_time_sec,
              attributeValidator) {}



