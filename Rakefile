require "bundler/gem_tasks"
require "rake/testtask"
require "rdoc/task"
require "hanna-nouveau"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*_test.rb']
end

task :default => :test

RDoc::Task.new do |t|
  t.rdoc_dir = ".rdoc"
  t.options += [
    "--line-numbers",
    "--title", "Shrine: Toolkit for file uploads",
    "--markup", "markdown",
    "--format", "hanna",
    "--main", "README.md",
  ]
  t.rdoc_files.add Dir[
    "README.md",
    "CHANGELOG.md",
    "lib/**/*.rb",
    "doc/*.md",
    "doc/release_notes/*.md",
  ]
end
