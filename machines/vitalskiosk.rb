require 'sinatra'
# require 'sinatra/base'
# require 'active_record'
require 'serialport'
require 'rack'
require 'logger'

require Sinatra::Application.root + '/lib/controller'
require Sinatra::Application.root + '/lib/tm2655'
require Sinatra::Application.root + '/lib/hom500kl'
  
class BPKiosk
  
  settings = YAML.load_file("settings.yml")
  
  configure do
    set :title, 'Open BP Kiosk'
    
    set :bpdevice, settings["bp"]["port"] 
    set :bpbaud, settings["bp"]["baud"]
    
    set :scaledevice, settings["scale"]["port"] 
    set :scalebaud, settings["scale"]["baud"]
    
    set :printer_port, 4242
  end    
end
