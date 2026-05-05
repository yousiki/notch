#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to add NotchKit framework target to Core/Notch.xcodeproj
# Uses xcodeproj gem

require 'xcodeproj'

PROJECT_PATH = File.join(__dir__, 'Core/Notch.xcodeproj')
NOTCHKIT_SOURCES_VERSION = File.join(__dir__, 'Core/NotchKit/Sources/Version/NotchKitVersion.swift')
NOTCHKIT_INFOPLIST = File.join(__dir__, 'Core/NotchKit/Resources/Info.plist')

puts "Opening project: #{PROJECT_PATH}"
project = Xcodeproj::Project.open(PROJECT_PATH)

# Check if NotchKit target already exists
existing = project.targets.find { |t| t.name == 'NotchKit' }
if existing
  puts "NotchKit target already exists - removing to rebuild cleanly"
  existing.remove_from_project
end

# --- 1. Add a new framework target ---
puts "Adding NotchKit framework target..."
notchkit_target = project.new_target(
  :framework,
  'NotchKit',
  :osx,
  '14.0'
)

# Set product name and bundle identifier
notchkit_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = 'NotchKit'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.theboredteam.NotchKit'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['DEFINES_MODULE'] = 'YES'
  config.build_settings['MACH_O_TYPE'] = 'mh_dylib'
  config.build_settings['INSTALL_PATH'] = '@rpath'
  config.build_settings['DYLIB_INSTALL_NAME_BASE'] = '@rpath'
  config.build_settings['LD_DYLIB_INSTALL_NAME'] = '@rpath/NotchKit.framework/Versions/A/NotchKit'
  config.build_settings['INFOPLIST_FILE'] = 'NotchKit/Resources/Info.plist'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['CODE_SIGN_IDENTITY'] = ''
  config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
  # Ensure sources are found - path relative to project
  config.build_settings['HEADER_SEARCH_PATHS'] = ['$(inherited)']
  config.build_settings['SWIFT_STRICT_CONCURRENCY'] = 'targeted'
  if config.name == 'Debug'
    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
    config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG $(inherited)'
  end
end

# --- 2. Add source group and file references ---
puts "Creating file groups..."
# Get or create Core group
main_group = project.main_group
core_group = main_group['Core'] || main_group.new_group('Core', 'Core')
notchkit_group = core_group['NotchKit'] || core_group.new_group('NotchKit', 'NotchKit')
sources_group = notchkit_group['Sources'] || notchkit_group.new_group('Sources', 'Sources')
version_group = sources_group['Version'] || sources_group.new_group('Version', 'Version')
resources_group = notchkit_group['Resources'] || notchkit_group.new_group('Resources', 'Resources')

# Add the version swift file
version_file_ref = version_group.new_file('NotchKitVersion.swift')
version_file_ref.path = 'NotchKit/Sources/Version/NotchKitVersion.swift'
version_file_ref.source_tree = 'SOURCE_ROOT'

# Add Info.plist reference
infoplist_ref = resources_group.new_file('Info.plist')
infoplist_ref.path = 'NotchKit/Resources/Info.plist'
infoplist_ref.source_tree = 'SOURCE_ROOT'

# --- 3. Add sources to the NotchKit target's Sources phase ---
puts "Adding source file to Sources build phase..."
sources_phase = notchkit_target.source_build_phase
sources_phase.add_file_reference(version_file_ref)

# Note: Info.plist is referenced by INFOPLIST_FILE build setting only,
# NOT added to the resources build phase (that would cause duplicate output)

# --- 4. Add NotchKit to the host app's "Embed Frameworks" phase ---
puts "Configuring host app embed frameworks phase..."
host_target = project.targets.find { |t| t.name == 'boringNotch' }
raise "Host target boringNotch not found!" unless host_target

# Find existing Embed Frameworks phase
embed_phase = host_target.copy_files_build_phases.find { |p| p.name == 'Embed Frameworks' }
if embed_phase.nil?
  puts "  Creating new Embed Frameworks phase..."
  embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  embed_phase.name = 'Embed Frameworks'
  embed_phase.symbol_dst_subfolder_spec = :frameworks
  host_target.build_phases << embed_phase
else
  puts "  Using existing Embed Frameworks phase..."
end

# Check if NotchKit is already in the embed phase
already_embedded = embed_phase.files.any? { |f|
  f.file_ref && f.file_ref.path.to_s.include?('NotchKit')
}

unless already_embedded
  puts "  Adding NotchKit.framework to embed phase..."
  # Add the NotchKit product (framework) to the embed phase
  notchkit_product = notchkit_target.product_reference

  embed_file = embed_phase.add_file_reference(notchkit_product)
  # Set CodeSignOnCopy and RemoveHeadersOnCopy
  embed_file.settings = { 'ATTRIBUTES' => ['CodeSignOnCopy', 'RemoveHeadersOnCopy'] }
  puts "  NotchKit.framework added to Embed Frameworks with CodeSignOnCopy"
end

# --- 5. Add target dependency from host to NotchKit ---
puts "Adding target dependency from boringNotch to NotchKit..."
# Check if dependency already exists
existing_dep = host_target.dependencies.find { |d|
  d.target && d.target.name == 'NotchKit'
}
unless existing_dep
  container_proxy = project.new(Xcodeproj::Project::Object::PBXContainerItemProxy)
  container_proxy.container_portal = project.root_object.uuid
  container_proxy.proxy_type = '1'
  container_proxy.remote_global_id_string = notchkit_target.uuid
  container_proxy.remote_info = 'NotchKit'

  dep = project.new(Xcodeproj::Project::Object::PBXTargetDependency)
  dep.target = notchkit_target
  dep.target_proxy = container_proxy
  host_target.dependencies << dep
  puts "  Target dependency added"
end

# --- 6. Link NotchKit in host's Frameworks build phase ---
puts "Linking NotchKit in host Frameworks build phase..."
frameworks_phase = host_target.frameworks_build_phase
already_linked = frameworks_phase.files.any? { |f|
  f.file_ref && (f.file_ref.path.to_s.include?('NotchKit') || f.file_ref.display_name.to_s.include?('NotchKit'))
}
unless already_linked
  frameworks_phase.add_file_reference(notchkit_target.product_reference)
  puts "  NotchKit.framework added to Frameworks phase"
end

# --- 7. Save the project ---
puts "Saving project..."
project.save
puts "Done! NotchKit target added successfully."

# Print summary
puts "\n=== Summary ==="
puts "Targets in project:"
project.targets.each { |t| puts "  - #{t.name}" }
