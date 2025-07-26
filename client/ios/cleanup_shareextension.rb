#!/usr/bin/env ruby

require 'fileutils'

project_file = 'Runner.xcodeproj/project.pbxproj'
backup_file = 'Runner.xcodeproj/project.pbxproj.backup'

puts "Backing up project file..."
FileUtils.cp(project_file, backup_file)

content = File.read(project_file)

# 1. Find all PBXCopyFilesBuildPhase blocks
copy_phases = content.scan(/([A-Z0-9]+) \/\* (.*?) \*\/ = \{\s*isa = PBXCopyFilesBuildPhase;.*?\};/m)

# 2. Identify all that reference ShareExtension.appex
share_phases = copy_phases.select { |id, block| block.include?('ShareExtension.appex') }

# 3. Keep only one with dstSubfolderSpec = 13
# (If none, just keep the first one)
to_keep = share_phases.find { |id, block| block.include?('dstSubfolderSpec = 13') } || share_phases.first
to_remove = share_phases - [to_keep]

if to_remove.any?
  puts "Removing #{to_remove.size} duplicate ShareExtension embed phases..."
  to_remove.each do |id, _|
    # Remove the entire block
    content.gsub!(/#{id} \/\* .*? \*\/ = \{\s*isa = PBXCopyFilesBuildPhase;.*?\};\n/m, "")
    # Remove from any buildPhases list
    content.gsub!(/#{id} \/\* .*? \*\/,?\n/, "")
  end
end

# 4. Remove duplicate ShareExtension.appex in files = (...) lists
content.gsub!(/(files = \([\s\S]*?)(B65EE2FA2E33111900C91CEC \/\* ShareExtension\.appex in [^,]+,?\n)([\s\S]*?B65EE2FA2E33111900C91CEC \/\* ShareExtension\.appex in [^,]+,?\n)/) do
  "#{$1}#{$2}#{$3}".sub(/B65EE2FA2E33111900C91CEC \/\* ShareExtension\.appex in [^,]+,?\n/, "")
end

puts "Writing cleaned project file..."
File.write(project_file, content)
puts "Done! Backup saved as #{backup_file}"
