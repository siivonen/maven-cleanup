#!/usr/bin/env ruby
require 'rexml/document'

if ARGV.size != 2  then
  puts("Usage: #{$0} /path/to/root/pom.xml 'mvn command to use'")
  exit 1
end
puts "This script will remove extra Maven dependencies of #{ARGV[0]} and all it's sub modules."
puts "Dependencies are removed one by one and if the command '#{ARGV[1]}' is successful the dependency is left out."

def get_dependencies(pom)
  array = Array.new
  REXML::Document.new(File.new(pom)).elements.each("project/dependencies/dependency") do | dependency |
    array << dependency.to_s
  end
  array
end

def get_poms_and_dependencies(pom, result)
  dir = File.dirname(pom)
  result[pom] = get_dependencies(pom)
  doc = REXML::Document.new(File.new(pom))
  REXML::XPath.match(doc, "//module").each do | mod |
    get_poms_and_dependencies(dir + "/" +mod.text + "/pom.xml", result)
  end
end

def replace(file, string, with)
  content = IO.read(file);
  File.open(file, 'w') { |f| f.write(content.gsub(string, with)) }
end

def remove_dependency_if_possible(pom, dependency)
  place_holder = "<!-- " + rand().to_s + " -->"
  replace(pom, dependency, place_holder)
  if system("cd #{File.dirname(pom)} && #{ARGV[1]} > /dev/null 2> /dev/null")
    puts "SUCCESS"
    replace(pom, /\n^\s*#{place_holder}\s*$/m, "")
  else
    puts "FAILED"
    replace(pom, place_holder, dependency)
  end
end

poms_and_dependencies = Hash.new
get_poms_and_dependencies(ARGV[0], poms_and_dependencies)
all_dependencies = Array.new
poms_and_dependencies.each { |pom,dependencies|  all_dependencies = all_dependencies + dependencies }
puts "Total number of pom.xml files #{poms_and_dependencies.size}, total number of dependencies #{all_dependencies.size}"

counter = 1
poms_and_dependencies.each do |pom, dependencies|
  puts "Handling #{dependencies.size} dependencies of #{pom}"
  dependencies.each do | dependency |
    group = dependency.match(/.*<groupId>(.*)<\/groupId>.*/)[1].strip
    artifact = dependency.match(/.*<artifactId>(.*)<\/artifactId>.*/)[1].strip
    print "Attempt #{counter}/#{all_dependencies.size}: remove #{group}:#{artifact}..."
    remove_dependency_if_possible(pom, dependency)
    counter = counter + 1
  end
end

