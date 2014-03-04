require "rubygems"
require "serialport"

class TM2655

  @@TIMEOUT = 60
  @@commands = {:start  => "\x16\x16\x01\x30\x20\x02\x53\x54\x03\x07",
                :stop   => "\x16\x16\x01\x30\x20\x02\x53\x50\x03\x03",
                :bp     => "\x16\x16\x01\x30\x30\x02\x52\x42\x03\x10",
                :pulse  => "\x16\x16\x01\x30\x30\x02\x52\x50\x03\x10"}
               
  @@syn = 22
  @@soh = 1
  @@stx = 2
  @@etx = 3
  @@ack = 6
  @@nak = 21  
  @@rs  = 30
               
  @@current = nil
  
  @result = ""

  @hex = ""
  
  $reading = false
      
  attr_reader :result, :log, :year, :month, :day, :hour, :minute, :command, :error, 
      :systolic, :mean_bp, :diastolic, :pulse_rate, :inflation_pressure, 
      :max_pulse_pressure, :model, :number_of_pulse, :pulses, :hex
  
  def initialize(device, baud)  
    
    puts "'#{device}', '#{baud}'"
    
    @sp = SerialPort.new("#{device}", baud)
    
    Thread.new {
      
      @log = "#{@log} $$ START $$ "
      
      while true do
        char = @sp.getc
        
        @log = "#{@log}#{char}"
        
        if $reading == false and char == @@syn          
          $reading = true
          
          @result = ""

	  @hex = ""
        end
        
        if $reading == true
          @result = "#{@result}#{char.chr}"

	  @hex = "#{@hex} 0x#{((char.to_s(16).to_s.upcase.rjust(2,0) rescue ("%02d" % char.to_s(16))) rescue char.to_s(16))}" # rescue nil
        end
        
        if $reading == true and (char == @@ack or char == @@nak or char == @@etx)
          $reading = false
        end
        
      end

    }
    
  end

  def log=(value)
    @log = value
  end

  def self.current
    @@current
  end
  
  def self.current=(machine)
    @@current = machine
  end
  
  def start
    self.run :start
  end
  
  def stop
    self.run :stop
  end
  
  def bp
    self.run :bp
  end
  
  def pulse
    self.run :pulse
  end
  
  def run(cmd)
    return nil if @sp.nil?

    cmd_hex = @@commands[cmd.to_sym]
    raise ArgumentError, "Unsupported command '#{cmd}'" unless cmd_hex
    
    @sp.write cmd_hex.to_s
  end
  
  def commands
    @@commands
  end
  
  def response
    # "|||00|TM2655|1910291429|RB|M|E00|S102|M 87|D 62|P 83|I17|L139||"
    # "|||00|TM2655|1310311616|RP|N 28|157, 13|155, 16|153,  9|151, 14|149, 18|147, 19|144, 12|142, 18|140, 18|138, 17|135, 16|132, 22|130, 23|128, 30|125, 32|122, 40|119, 54|116, 52|113, 65|109, 61|106, 64|103, 78| 99, 74| 96, 80| 93, 93| 90, 88| 87,105| 84, 98|"
    
    resp = result.gsub(/[[:cntrl:]]/, "|") rescue ""
    
    terms = resp.split("|")
    
    if terms.length > 6
          
      @year   = terms[5][0, 2]
      @month  = terms[5][2, 2]
      @day    = terms[5][4, 2]
      @hour   = terms[5][6, 2]
      @minute = terms[5][8, 2]
      
      @command = terms[6]
        
      if terms[6].upcase == "RB"
        @error = terms[8].gsub(/E/i, "").strip
        
        @systolic = terms[9].gsub(/S/i, "").strip
        @mean_bp = terms[10].gsub(/M/i, "").strip
        @diastolic = terms[11].gsub(/D/i, "").strip
        @pulse_rate = terms[12].gsub(/P/i, "").strip
        @inflation_pressure = terms[13].gsub(/I/i, "").strip
        @max_pulse_pressure = terms[14].gsub(/L/i, "").strip
        
      elsif terms[6].upcase == "RP"
        @error = nil
        
        @pulses = []
        
        count = terms[7].gsub(/N/i, "").strip.to_i
        
        (0..(count - 1)).each do |pos|
          
          items = terms[(8 + pos)].split(",")
          
          @pulses << [items[0].strip.to_i, items[1].strip.to_i]
          
        end
        
      end
    end
    
    resp
  end
  
  def close
    @log = ""
    @result = ""
    @hex = ""  
    $reading = false
    @sp.close
    @sp = nil
  end

end
