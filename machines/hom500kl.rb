require "rubygems"
require "serialport"

class HoM500KL

  @@esc = "\e" # 27
  @@end = "E" # 69

  $reading = false
  
  $last_reading = ""
  
  attr_reader :weight, :height, :bmi, :units, :current_reading, :read_time
      
  def initialize
    
    @weight = 0.0
    @height = 0.0
    @bmi = 0.0
    @units = ""
    
    @current_reading = ""
      
    settings = YAML.load_file("settings.yml") rescue {"baud"=>9600, "port"=>"/dev/ttyUSB0"}
    
    port = settings["scale"]["port"].strip
    baud = settings["scale"]["baud"].to_i
      
    @sp = SerialPort.new(port, baud) # rescue nil
    
    return if @sp.nil?
    
    Thread.new {
      while true do
        char = @sp.getc
        
        if !$reading and char == @@esc          
          $reading = true
          
          @current_reading = ""
        end
        
        # print char.to_s if char.to_s.match(/[[:print:]]/)
        
        if char.to_s.match(/[[:print:]]/)
        
            if $reading and char == @@end
              
              @reading = false
              
              @current_reading = "#{@current_reading}#{(char.to_s.match(/[[:print:]]/) ? char : "U")}"
              
              $last_reading = @current_reading
              
              result = $last_reading.match(/(w[^h]+)(h[^b]+)(b[^n]+)(n[^e])/i)
        
              @current_reading = ""
              
              if result 
              
                @weight = result[1].gsub(/w/i, "").to_f rescue 0.0
                @height = result[2].gsub(/h/i, "").to_f rescue 0.0
                @bmi = result[3].gsub(/b/i, "").to_f rescue 0.0
                @units = result[4].gsub(/n/i, "") rescue ""
                
                @read_time = Time.now.strftime("%Y-%m-%d %H:%M:%S")
              
              end
              
              sleep(10)

            elsif $reading
            
              @current_reading = "#{@current_reading}#{(char.to_s.match(/[[:print:]]/) ? char : "U")}"
              
            end
            
        end

      end
    }
    
  end

end
