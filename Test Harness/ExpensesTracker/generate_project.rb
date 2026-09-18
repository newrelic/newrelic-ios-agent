#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates ExpensesTracker.xcodeproj.
#
# The project is generated rather than committed as a hand-edited pbxproj so the wiring to the local agent
# is explicit and reviewable: the Agent.xcodeproj subproject reference, the dependency on the Agent_iOS
# framework target, and the link + embed of NewRelic.framework are all visible here. HomeSearch's generator
# established the approach; this one differs only in walking nested source folders, since the app splits its
# screens into Screens/UIKit and Screens/SwiftUI.
#
# Re-run after adding source files:
#
#     cd "Test Harness/ExpensesTracker" && ruby generate_project.rb
#
# Requires the xcodeproj gem (already in this repo's Gemfile).

require 'xcodeproj'
require 'pathname'
require 'fileutils'

ROOT          = Pathname.new(__dir__).realpath
REPO_ROOT     = ROOT.parent.parent
PROJECT_PATH  = ROOT + 'ExpensesTracker.xcodeproj'
SOURCE_DIR    = ROOT + 'ExpensesTracker'
SWIFTER_DIR   = REPO_ROOT + 'Test Harness/NRTestApp/NRTestAppUITests/Swifter'
AGENT_PROJECT = REPO_ROOT + 'Agent.xcodeproj'

# iOS 17: the app uses Observation-era SwiftUI APIs (`.background(_:in:)` shorthand, `TextField(axis:)`,
# `Button(_:systemImage:)`), and every simulator this repo is tested against is well past it.
DEPLOYMENT_TARGET = '17.0'
BUNDLE_ID         = 'com.newrelic.ExpensesTracker'

abort "Missing Swifter at #{SWIFTER_DIR}" unless SWIFTER_DIR.directory?
abort "Missing #{AGENT_PROJECT}" unless AGENT_PROJECT.exist?
abort "Missing app sources at #{SOURCE_DIR}" unless SOURCE_DIR.directory?

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH)

target = project.new_target(:application, 'ExpensesTracker', :ios, DEPLOYMENT_TARGET)

# ── Build settings ────────────────────────────────────────────────────────────────────────────────
target.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER']  = BUNDLE_ID
  settings['PRODUCT_NAME']               = '$(TARGET_NAME)'
  settings['INFOPLIST_FILE']             = 'ExpensesTracker/Info.plist'
  settings['GENERATE_INFOPLIST_FILE']    = 'NO'
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
  settings['SWIFT_VERSION']              = '5.0'
  settings['TARGETED_DEVICE_FAMILY']     = '1,2'
  # Nothing here is signed: the app runs on the simulator, and requiring a team would make a fresh clone
  # fail to build for a reason that has nothing to do with the agent.
  settings['CODE_SIGN_STYLE']            = 'Automatic'
  settings['CODE_SIGNING_REQUIRED']      = 'NO'
  settings['CODE_SIGNING_ALLOWED']       = 'NO'
  settings['ENABLE_PREVIEWS']            = 'YES'
  settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  settings['LD_RUNPATH_SEARCH_PATHS']    = ['$(inherited)', '@executable_path/Frameworks']
  settings['MARKETING_VERSION']          = '1.0'
  settings['CURRENT_PROJECT_VERSION']    = '1'
  settings['CLANG_ENABLE_MODULES']       = 'YES'
  settings['SWIFT_EMIT_LOC_STRINGS']     = 'YES'
end

# ── App sources, mirroring the on-disk folder structure ───────────────────────────────────────────
# Walked recursively, unlike HomeSearch's flat list, because Screens has UIKit and SwiftUI beneath it.
app_group = project.new_group('ExpensesTracker', 'ExpensesTracker')

def add_sources(group, dir, target)
  Dir.glob(dir + '*.swift').sort.each do |path|
    file = group.new_file(Pathname.new(path).basename.to_s)
    target.add_file_references([file])
  end

  Dir.glob(dir + '*').select { |path| File.directory?(path) }.sort.each do |path|
    name = Pathname.new(path).basename.to_s
    # Asset catalogues are directories too; they are added as resources further down.
    next if name.end_with?('.xcassets')

    add_sources(group.new_group(name, name), Pathname.new(path) + '', target)
  end
end

add_sources(app_group, SOURCE_DIR + '', target)

# Info.plist is referenced but never compiled or copied — INFOPLIST_FILE handles it.
app_group.new_file('Info.plist')

# ── Resources ─────────────────────────────────────────────────────────────────────────────────────
assets = app_group.new_file('Assets.xcassets')
target.add_resources([assets])

# ── Vendored Swifter, referenced in place rather than copied ───────────────────────────────────────
# Both stub servers need an HTTP server. Swifter already lives in this repo for NRTestApp, and HomeSearch
# references it from there too: one copy, one place to update.
swifter_group = project.new_group('Swifter', SWIFTER_DIR.relative_path_from(ROOT).to_s)
Dir.glob(SWIFTER_DIR + '*.swift').sort.each do |path|
  file = swifter_group.new_file(Pathname.new(path).basename.to_s)
  target.add_file_references([file])
end

# ── The local New Relic agent ──────────────────────────────────────────────────────────────────────
# Agent.xcodeproj is added as a subproject so the app links the framework built from THIS working tree.
# That is what makes the MobileViews API available at all: the .NRMobile* SwiftUI modifiers and the
# AutomaticMobileViews / ManualMobileViews feature flags do not exist in the published XCFramework, only on
# this branch. Adding a reference to a path ending in .xcodeproj makes xcodeproj build the whole subproject
# wiring for us: container item proxies, reference proxies for each product, a Products group, and the
# project_references entry on the root object.
agent_ref = project.main_group.new_reference(AGENT_PROJECT.relative_path_from(ROOT).to_s)
agent_ref.name = 'Agent.xcodeproj'

agent_project = Xcodeproj::Project.open(AGENT_PROJECT)
agent_ios = agent_project.native_targets.find { |t| t.name == 'Agent_iOS' }
abort 'Could not find the Agent_iOS target in Agent.xcodeproj' if agent_ios.nil?

# Agent.xcodeproj produces THREE products all named NewRelic.framework — iOS, tvOS and watchOS — so picking
# the proxy by name would be a coin flip between platforms. Match on the remote UUID of the Agent_iOS
# product instead, which is unambiguous.
ios_product_uuid = agent_ios.product_reference.uuid
framework_proxy = project.objects.select { |object|
  object.is_a?(Xcodeproj::Project::Object::PBXReferenceProxy)
}.find { |proxy|
  proxy.remote_ref&.remote_global_id_string == ios_product_uuid
}

if framework_proxy.nil?
  abort "Could not find a product proxy for Agent_iOS (#{ios_product_uuid}) in the subproject"
end

# Build the agent before the app.
dependency_proxy = project.new(Xcodeproj::Project::Object::PBXContainerItemProxy)
dependency_proxy.container_portal = agent_ref.uuid
dependency_proxy.proxy_type = '1' # reference to a native target
dependency_proxy.remote_global_id_string = agent_ios.uuid
dependency_proxy.remote_info = 'Agent_iOS'

dependency = project.new(Xcodeproj::Project::Object::PBXTargetDependency)
dependency.name = 'Agent_iOS'
dependency.target_proxy = dependency_proxy
target.dependencies << dependency

# Link it…
target.frameworks_build_phase.add_file_reference(framework_proxy)

# …and embed it, so the dynamic framework is present at runtime.
embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
embed_phase.name = 'Embed Frameworks'
embed_phase.symbol_dst_subfolder_spec = :frameworks
embed_phase.run_only_for_deployment_postprocessing = '0'
target.build_phases << embed_phase

embed_build_file = embed_phase.add_file_reference(framework_proxy)
embed_build_file.settings = { 'ATTRIBUTES' => %w[RemoveHeadersOnCopy] }

# ── Scheme ────────────────────────────────────────────────────────────────────────────────────────
project.save

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.set_launch_target(target)
scheme.save_as(PROJECT_PATH.to_s, 'ExpensesTracker', true)

puts "Generated #{PROJECT_PATH}"
puts "  target       ExpensesTracker (iOS #{DEPLOYMENT_TARGET})"
puts "  app sources  #{Dir.glob(SOURCE_DIR + '**/*.swift').count} Swift files"
puts "  swifter      #{Dir.glob(SWIFTER_DIR + '*.swift').count} Swift files (referenced in place)"
puts "  links        NewRelic.framework from Agent.xcodeproj → Agent_iOS"
