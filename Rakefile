# Will this ever be useful? ...
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

task :extract_fixtures do
  unless File.directory? 'features/support/blog.git'
    Dir.chdir('features/support') { sh "tar xzf blog.git.tgz" }
  end
end

require 'cucumber/rake/task'
Cucumber::Rake::Task.new :cucumber => :extract_fixtures

namespace :cuke do
  Cucumber::Rake::Task.new(:wip => :extract_fixtures) do |t|
    t.cucumber_opts = '--tags @wip'
  end
end

task :default => [:spec, :cucumber]
