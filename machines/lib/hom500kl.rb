require "rubygems"
require "serialport"

class HoM500KL

  @@esc = "\e" # 27
  @@end = "E" # 69

  $reading = false
  
  $last_reading = ""
  
  attr_reader :weight, :height, :bmi, :units, :current_reading, :read_time
      
  def initialize(port, baud)
    
    @weight = 0.0
    @height = 0.0
    @bmi = 0.0
    @units = ""
    
    @current_reading = ""
      
    @sp = SerialPort.new(port, baud) rescue nil
    
    return if @sp.nil?
    
    logger = Logger.new 'log/hom500kl.log'
    
    logger.info "Status: Initialized with #{port} and #{baud}"
    
    Thread.new {
      while true do
        char = @sp.getc
        
        if !$reading and char.chr == @@esc          
          $reading = true
          
          @current_reading = ""
        end
        
        if char.to_s.match(/[[:print:]]/)
        
            if $reading and char.chr == @@end
              
              @reading = false
              
              @current_reading = "#{@current_reading}#{(char.chr.to_s.match(/[[:print:]]/) ? char.chr : "U")}"
              
              $last_reading = @current_reading
              
              result = $last_reading.match(/(w[^h]+)(h[^b]+)(b[^n]+)(n[^e])/i)
        
              @current_reading = ""
              
              if result 
              
                @weight = result[1].gsub(/w/i, "").to_f rescue 2.0
                @height = result[2].gsub(/h/i, "").to_f rescue 2.0
                @bmi = result[3].gsub(/b/i, "").to_f rescue 2.0
                @units = result[4].gsub(/n/i, "") rescue ""
                
                @read_time = Time.now.strftime("%Y-%m-%d %H:%M:%S")
              
              else
              
                @weight = 3.0
                @height = 3.0
              
              end
              
              sleep(20)

            elsif $reading
            
              @current_reading = "#{@current_reading}#{(char.chr.to_s.match(/[[:print:]]/) ? char.chr : "U")}"
              
            end
            
        else
        
          @weight = 1.0
          @height = 1.0
          @bmi = 1.0
          @units = "m"
          
          @read_time = ""
            
        end

      end
    }
    
  end

  def close
    @sp.close
  end

end
