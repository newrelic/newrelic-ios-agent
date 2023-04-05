
Pod::Spec.new do |s|
  s.name                   = "NewRelicAgent"
  s.version                = "7.4.3-rc.192"
  s.summary                = "Real-time performance data with your next iOS app release."
  s.homepage               = "http://newrelic.com/mobile-monitoring"
  s.license                = { :type => "Commercial", :file => "LICENSE" }
  s.author                 = { "New Relic, Inc." => "support@newrelic.com" }
  s.source                 = { :http => "https://download.newrelic.com/ios-v5/NewRelic_XCFramework_Agent_7.4.3-rc.192.zip" }
  s.ios.deployment_target  = '9.0'
  s.tvos.deployment_target = '9.0'
  s.vendored_frameworks    = "NewRelic.xcframework"
  s.preserve_paths         = "*.xcframework"
  s.frameworks             = "SystemConfiguration"
  s.ios.frameworks         = "CoreTelephony"
  s.libraries              = "z","c++"
  s.requires_arc           = false
end