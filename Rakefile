require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

task default: :test

unless RUBY_ENGINE == "jruby"
  require "rdoc/task"

  RDoc::Task.new do |t|
    t.rdoc_dir = "website/build/rdoc"
    t.options += [
      "--line-numbers",
      "--title", "Shrine: Toolkit for file uploads",
      "--markup", "markdown",
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
end

namespace :website do
  task :publish => :build do
    sh "git switch gh-pages"
    sh "cp -R website/build/* ."
    sh "git add --all"
    sh "git commit -m 'Update website'"
    sh "git push origin gh-pages"
    sh "git switch master"
  end

  task :build do
    sh "yarn build", chdir: "website"
    Rake::Task["rdoc"].invoke
  end
end
