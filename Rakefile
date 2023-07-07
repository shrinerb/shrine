require "bundler/gem_tasks"
require "rake/testtask"
require "rdoc/task"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

task default: :test

RDoc::Task.new do |t|
  t.rdoc_dir = "website/build/rdoc"
  t.options += [
    "--line-numbers",
    "--title", "Shrine: Toolkit for file uploads",
    "--markup", "markdown",
    "--format", "hanna",
    "--main", "README.md",
    "--visibility", "public",
  ]
  t.rdoc_files.add Dir[
    "README.md",
    "CHANGELOG.md",
    "lib/**/*.rb",
    "doc/*.md",
    "doc/release_notes/*.md",
  ]
end

namespace :website do
  task :build do
    sh "yarn build", chdir: "website"
    Rake::Task["rdoc"].invoke
  end
end
