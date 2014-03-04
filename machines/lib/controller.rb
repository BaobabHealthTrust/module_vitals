#enable :sessions
use Rack::Session::Pool, :expire_after => 2592000

require "json"

helpers do
    
end

get '/bp' do  
  if $bpmachine.nil?
    $bpmachine = TM2655.new settings.bpdevice, settings.bpbaud
  end
  erb :index  
end

get '/read' do
  if $bpmachine.nil?
    $bpmachine = TM2655.new settings.bpdevice, settings.bpbaud
  end
  erb :read  
end

get '/stop' do
  if $bpmachine.nil?
    $bpmachine = TM2655.new settings.bpdevice, settings.bpbaud
  end
  
  $bpmachine.stop
  
  sleep 20
end

get '/start' do
  if $bpmachine.nil?
    $bpmachine = TM2655.new settings.bpdevice, settings.bpbaud
  end
  
  $bpmachine.start
  
  sleep 30
  
  $bpmachine.response
  
  $bpmachine.bp 
  
  sleep 20
  
  $bpmachine.response 
  
  $bpmachine.pulse 
  
  sleep 20
  
  $bpmachine.response
  
end

get '/readings' do
  if $bpmachine.nil?
    $bpmachine = TM2655.new settings.bpdevice, settings.bpbaud
  end
  erb :readings  
end

get '/display_bp' do
  if $bpmachine.nil?
    $bpmachine = TM2655.new settings.bpdevice, settings.bpbaud
  end
  
  result = {}
  
  result["systolic"] = $bpmachine.systolic rescue nil
  result["diastolic"] = $bpmachine.diastolic rescue nil
  result["pulse"] = $bpmachine.pulse_rate rescue nil
  result["pulse_env"] = $bpmachine.pulses rescue []
    
  # $bpmachine.close
  
  result.to_json  
    
end

get '/weight' do 
  
  if $hom500kl.nil?  
    $hom500kl = HoM500KL.new settings.scaledevice, settings.scalebaud   

    sleep 10  
  end           
    
  result = $hom500kl.weight
  
  result.to_s
  
end

get '/height' do 
  
  if $hom500kl.nil?  
    $hom500kl = HoM500KL.new settings.scaledevice, settings.scalebaud   

    sleep 10  
  end           
    
  result = $hom500kl.height
  
  result.to_s
  
end

