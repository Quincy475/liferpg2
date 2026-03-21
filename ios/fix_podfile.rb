# fix_podfile.rb
# Run this script from the ios/ directory: ruby fix_podfile.rb
# It patches the Podfile to remove the -G compiler flag that causes build failures.

podfile_path = File.join(__dir__, 'Podfile')

unless File.exist?(podfile_path)
  puts "ERROR: Podfile not found at #{podfile_path}"
  exit 1
end

content = File.read(podfile_path)

fix_snippet = <<~'RUBY'
    target.build_configurations.each do |config|
        config.build_settings.delete('OTHER_CFLAGS')
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      end
RUBY

if content.include?("config.build_settings.delete('OTHER_CFLAGS')")
  puts "Podfile already patched, skipping."
  exit 0
end

# Insert fix after flutter_additional_ios_build_settings(target)
patched = content.gsub(
  /flutter_additional_ios_build_settings\(target\)/,
  "flutter_additional_ios_build_settings(target)\n#{fix_snippet}"
)

if patched == content
  puts "WARNING: Could not find insertion point in Podfile. Patch not applied."
  puts "Make sure your Podfile contains: flutter_additional_ios_build_settings(target)"
  exit 1
end

File.write(podfile_path, patched)
puts "Podfile patched successfully!"