require "bundler/gem_tasks"
require "pathname"
require "rake/testtask"
require "securerandom"

ENV['LUCA_TEST_DIR'] = (Pathname(__dir__) / 'tmp' / SecureRandom.uuid).to_s
FileUtils.mkdir_p(ENV['LUCA_TEST_DIR'])

Rake::TestTask.new(:test) do |t|
  FileUtils.chdir(ENV['LUCA_TEST_DIR']) do
    t.libs << "test"
    t.libs << "lib"
    t.test_files = FileList["test/**/*_test.rb"]
  end
end

task :default => :test
