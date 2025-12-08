# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever


#commented out during AWS migration as job has been failing and needs
re-designing

#every 1.day, at: '4:30 am' do
#  runner "SymbolsetSync::ArasaacJob.perform_now"
#end

# Daily safety warmer for Directus cached collections
# Runs at 4:30 am to ensure no cache can be stale for more than ~24 hours
every 1.day, at: '4:30 am' do
  runner "DirectusDailyWarmerJob.perform_now"
end
