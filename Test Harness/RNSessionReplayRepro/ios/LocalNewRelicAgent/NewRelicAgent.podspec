# Stands in for the published NewRelicAgent pod so the repro links the agent
# built from this repo (scripts/build-local-agent.sh). Simulator only.
Pod::Spec.new do |s|
  s.name                  = "NewRelicAgent"
  s.version               = "7.7.11"
  s.summary               = "New Relic iOS agent built from the local working tree."
  s.homepage              = "http://newrelic.com/mobile-monitoring"
  s.license               = { :type => 'Apache License, Version 2.0' }
  s.author                = { "New Relic, Inc." => "support@newrelic.com" }
  s.source                = { :path => "." }
  s.ios.deployment_target = '15.0'
  s.vendored_frameworks   = "NewRelic.xcframework"
  s.ios.frameworks        = "CoreTelephony", "SystemConfiguration"
  s.libraries             = "z", "c++"
  s.requires_arc          = false
end
