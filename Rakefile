require "bundler/gem_tasks"
require "rake/testtask"
require "rdoc/task"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*_test.rb']
end

task :default => :test

RDoc::Task.new do |t|
  t.rdoc_dir = "www/build/rdoc"
  t.options += [
    "--line-numbers",
    "--title", "Shrine: Toolkit for file uploads",
    "--markup", "markdown",
    "--format", "hanna", # requires the hanna-nouveau gem
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

namespace :website do
  task :build do
    sh "rm -rf www/build"
    sh "mkdir -p www/build"
    sh "cp www/index.html www/build/index.html"
    sh "rake rdoc"
  end

  task :publish => :build do
    sh "git subtree push --prefix www/build origin gh-pages"
  end
end
