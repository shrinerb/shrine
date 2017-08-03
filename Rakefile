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

task rdoc: "website:rdoc_github_links"

namespace :website do
  task :build do
    sh "cd www; bundle exec jekyll build; cd .."
    sh "rake rdoc"
  end

  task :rdoc_github_links do
    begin
      require "oga"

      revision = `git rev-parse HEAD`.chomp
      github_icon = '<img src="/images/github.png" width=13 height=12 style="position:absolute; margin-left:5px;">'

      Dir["www/build/rdoc/classes/**/*.html"].each do |class_file|
        html = File.read(class_file)
        document = Oga.parse_html(html)

        file_link = document.css(".header .paths li a").first
        file_link_html = file_link.to_xml

        file_link["href"] = "https://github.com/janko-m/shrine/blob/#{revision}/#{file_link.text}"

        new_html = html.sub(file_link_html, "#{file_link.to_xml} #{github_icon}")

        File.write(class_file, new_html)
      end
    rescue LoadError
    end
  end
end
