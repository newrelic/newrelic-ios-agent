
Pod::Spec.new do |s|
  s.name                   = "NewRelicAgent"
  s.version                = ""
  s.summary                = "Real-time performance data with your next iOS app release."
  s.homepage               = "http://newrelic.com/mobile-monitoring"
  s.license                = { :type => "Commercial", :file => "LICENSE" }
  s.author                 = { "New Relic, Inc." => "support@newrelic.com" }
  s.source                 = { :http => "https://download.newrelic.com/ios_agent/NewRelic_XCFramework_Agent_.zip" }
  s.ios.deployment_target  = '9.0'
  s.tvos.deployment_target = '9.0'
  s.vendored_frameworks    = "NewRelic.xcframework"
  s.preserve_paths         = "*.xcframework"
  s.frameworks             = "SystemConfiguration"
  s.ios.frameworks         = "CoreTelephony"
  s.libraries              = "z","c++"
  s.requires_arc           = false
end