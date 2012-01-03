#!/usr/bin/env ruby
require 'rexml/document'

if ARGV.size < 1
  puts("Usage: #{$0} <path_to_root_pom_xml>")
  exit 1
end
puts "This script will remove extra dependency management dependencies from #{ARGV[0]}"

def get_dependency_managements(pom)
  deps = Array.new
  REXML::Document.new(File.new(pom)).elements.each("project/dependencyManagement/dependencies/dependency") do | dep |
    deps = deps << dep.to_s
  end
  deps
end

def get_content(dep, pom, tag)
  return "" if not dep.to_s.include?("<#{tag}>")
  doc = REXML::Document.new(File.new(pom))
  value = ""
  value = doc.elements["project/parent/#{tag}"].text if doc.elements["project/parent/#{tag}"]
  value = doc.elements["project/#{tag}"].text if doc.elements["project/#{tag}"]
  dep.to_s.sub(/<\/#{tag}>.*/m, "").sub(/.*<#{tag}>/m, "").sub("${project.#{tag}}", value).sub("${pom.#{tag}}", value)
end

def unify_dependency(dep, pom)
  dep = get_content(dep, pom, "groupId") + ":" + get_content(dep, pom, "artifactId") + ":" + get_content(dep, pom, "type") + ":" + get_content(dep, pom, "classifier")
end

def get_dependencies(pom)
  deps = Array.new
  REXML::Document.new(File.new(pom)).elements.each("project/dependencies/dependency") do | dep |
    deps = deps << unify_dependency(dep, pom)
  end
  deps
end

def get_all_dependencies(pom)
  deps = get_dependencies(pom)
  doc = REXML::Document.new(File.new(pom))
  REXML::XPath.match(doc, "//module").each do | mod |
    deps = deps | get_all_dependencies(File.dirname(pom) + "/" + mod.text + "/pom.xml")
  end
  deps
end

def remove_dependency(pom, dep)
  puts "Removing #{unify_dependency(dep, pom)}"
  content = IO.read(pom)
  tmp = rand().to_s
  File.open(pom, 'w') do |f|
    f.write(content.sub(dep.to_s, tmp).sub(/\n\s*#{tmp}/, ""))
  end
end

deps = get_all_dependencies(ARGV[0])
get_dependency_managements(ARGV[0]).each do | dep |
  remove_dependency(ARGV[0], dep) if not deps.include?(unify_dependency(dep, ARGV[0]))
end

