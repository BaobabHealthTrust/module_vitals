require 'sinatra'
require Sinatra::Application.root + '/vitalskiosk'

# Setup the logging
FileUtils.mkdir_p('log') unless File.exists?('log')
log = File.new("log/sinatra.log", "a")
$stdout.reopen(log)
$stderr.reopen(log)

Logger.class_eval { alias :write :'<<' }
logger = Logger.new 'log/app.log'

use Rack::CommonLogger, logger

run Sinatra::Application
