# fix_podfile.rb
# Run this script from the ios/ directory: ruby fix_podfile.rb
# It patches the Podfile to remove the -G compiler flag that causes build failures.

puts "=== fix_podfile.rb gestart ==="
puts "Huidige map: #{Dir.pwd}"

podfile_path = File.join(__dir__, 'Podfile')
puts "Zoeken naar Podfile op: #{podfile_path}"

unless File.exist?(podfile_path)
  puts "ERROR: Podfile niet gevonden op #{podfile_path}"
  puts "Bestanden in huidige map:"
  Dir.glob("*").each { |f| puts "  #{f}" }
  exit 1
end

puts "Podfile gevonden!"
content = File.read(podfile_path)
puts "--- Huidige Podfile inhoud ---"
puts content
puts "--- Einde Podfile inhoud ---"

fix_snippet = <<~RUBY
    target.build_configurations.each do |config|
        config.build_settings.delete('OTHER_CFLAGS')
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      end
RUBY

if content.include?("config.build_settings.delete('OTHER_CFLAGS')")
  puts "Podfile is al gepatcht, niets te doen."
  exit 0
end

puts "Patch nog niet aanwezig, bezig met patchen..."

patched = content.gsub(
  /flutter_additional_ios_build_settings\(target\)/,
  "flutter_additional_ios_build_settings(target)\n#{fix_snippet}"
)

if patched == content
  puts "ERROR: Kon invoegpunt niet vinden in Podfile."
  puts "Zorg dat Podfile de regel bevat: flutter_additional_ios_build_settings(target)"
  exit 1
end

File.write(podfile_path, patched)
puts "Podfile succesvol gepatcht!"
puts "--- Nieuwe Podfile inhoud ---"
puts File.read(podfile_path)
puts "--- Einde nieuwe Podfile inhoud ---"
puts "=== fix_podfile.rb klaar ==="