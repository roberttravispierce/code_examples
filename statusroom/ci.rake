# task :mig do
#   puts 'rake db:migrate RAILS_ENV="development"'
#   system "rake db:migrate RAILS_ENV='development'"
#   puts "rake db:test:clone"
#   system "rake db:test:clone"
#   if !ENV['a'].nil?
#     puts "NOT RUNNING: rake annotate_models"
#   else
#     system "rake annotate_models"
#   end
# end

task :default => [:test, :features]

desc "Run tests and commit files"
task :ci => [:check_uncommitted_files, :default, :commit]

desc "Update to latest code"
task :up do
  puts `git pull`
end

desc "Commit files"
task :commit => [:check_uncommitted_files] do
  raise "\n\n!!!!! You must specify a message for the commit (example: m='some message') !!!!!\n\n" if ENV['m'].nil?
  puts `git commit -a -m "#{ENV['m']}"`
end

desc "Push to Github repo"
task :push => [:test] do
  puts "git push"
  puts `git push`
end

desc "Deploy to current environment"
task :deploy do
  status_result = `git status`
  branch = status_result[/# On branch .*/].gsub('# On branch ', '')
  status_message = `git log -1 --pretty=oneline`
  puts `cap #{branch} deploy -s message=#{status_message}`
end

desc "Check uncommitted files"
task :check_uncommitted_files do
  status_result = `git status`
  if status_result[/Untracked files:/m]
    puts status_result
    raise "\n\n!!!!! You have local files not added!!!!!\n\n"
  end 
end

namespace :deploy do
  [:staging, :production, :pacificadvisors].each do |environ|
    desc "Deploy to #{environ}"
    task environ do
      puts `git checkout #{environ}`
      puts `git merge master`
      puts `git push`
      puts `cap #{environ} deploy`
      puts `git checkout master`
    end
  end
end