require "bundler/gem_tasks"
require "rake/testtask"
require "rdoc/task"

test_files  = FileList["test/**/*_test.rb"]
test_files -= ["test/s3_test.rb"] unless ENV["S3"]

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = test_files
  t.warning = false
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
    sh "cd www; bundle exec jekyll build; cd .."
    sh "rake rdoc"
  end

  task :publish => :build do
    sh "git subtree push --prefix www/build origin gh-pages"
  end
end
