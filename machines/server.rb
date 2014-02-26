#!/usr/bin/ruby

require 'rubygems'
require "yaml"
require 'webrick'
require 'json'
require "#{Dir.pwd}/tm2655.rb"
require "#{Dir.pwd}/hom500kl.rb"

class Home < WEBrick::HTTPServlet::AbstractServlet

  def do_GET(request, response)
    status, content_type, body = print_result(request)

    response.status = status
    response['Content-Type'] = content_type
    response.body = body
  end

  def print_result(request)
  
    path = request.path
    
    puts "PATH: '" + request.path + "'"

    file = File.open((path.strip.match(/^\/$/) ? "index.html" : path.strip[1, request.path.strip.length - 1]), "r");
    
    content = file.read
    
    file.close
    
    if $tm2655.nil?
      
      settings = YAML.load_file("settings.yml")
      
      port = settings["bp"]["port"].strip
      baud = settings["bp"]["baud"].to_i
      
      $tm2655 = TM2655.new(port, baud) rescue nil
    
    end
    
    return 200, "text/html", content
  end  
  
end

class ReadBPMachine < WEBrick::HTTPServlet::AbstractServlet

  def do_GET(request, response)
    status, content_type, body = print_result(request)

    response.status = status
    response['Content-Type'] = content_type
    response.body = body
  end

  def print_result(request)
  
    file = File.open("read.html", "r");
    
    content = file.read
    
    file.close
    
    return 200, "text/html", content
  end  
end

class StartBPMachine < WEBrick::HTTPServlet::AbstractServlet

  def do_GET(request, response)
    status, content_type, body = print_result(request)

    response.status = status
    response['Content-Type'] = content_type
    response.body = body
  end

  def print_result(request)
  
    file = File.open("read.html", "r");
    
    content = file.read
    
    file.close
    
    return 200, "text/html", content
  end  
end

class ReadScale < WEBrick::HTTPServlet::AbstractServlet

  def do_GET(request, response)
    status, content_type, body = print_result(request)

    response.status = status
    response['Content-Type'] = content_type
    response.body = body
  end

  def print_result(request)
      
    if @@hom500kl.nil?
      
      @@hom500kl = HoM500KL.new
      
      sleep 10            
      
    end
    
    result = {
      "weight" => @@hom500kl.weight,
      "height" => @@hom500kl.height,
      "bmi" => @@hom500kl.bmi,
      "units" => @@hom500kl.units,
      "read" => @@hom500kl.read_time
    }
    
    return 200, "text/json", result.to_json
  end  
end

class ReadWeight < WEBrick::HTTPServlet::AbstractServlet

  def do_GET(request, response)
    status, content_type, body = print_result(request)

    response.status = status
    response['Content-Type'] = content_type
    response.body = body
  end

  def print_result(request)
      
    if @@hom500kl.nil?
      
      @@hom500kl = HoM500KL.new
      
      sleep 10            
      
    end
    
    result = {:value => @@hom500kl.weight}
    
    return 200, "text/json", result.to_json
  end  
end

class ReadHeight < WEBrick::HTTPServlet::AbstractServlet

  def do_GET(request, response)
    status, content_type, body = print_result(request)

    response.status = status
    response['Content-Type'] = content_type
    response.body = body
  end

  def print_result(request)
      
    if @@hom500kl.nil?
      
      @@hom500kl = HoM500KL.new
      
      sleep 10            
      
    end
    
    result = {:value => @@hom500kl.height}
    
    return 200, "text/json", result.to_json
  end  
end

unless ARGV[0].nil?
  if $0 == __FILE__ then
    server = WEBrick::HTTPServer.new(:Port => ARGV[0])
    server.mount "/readbp", ReadBPMachine
    server.mount "/startbp", StartBPMachine
    server.mount "/", Home
    server.mount "/readscale", ReadScale
    server.mount "/weight", ReadWeight
    server.mount "/height", ReadHeight
    trap "INT" do server.shutdown end
    
    @@hom500kl = HoM500KL.new rescue nil
    
    settings = YAML.load_file("settings.yml")
    
    port = settings["bp"]["port"].strip
    baud = settings["bp"]["baud"].to_i
      
    $tm2655 = TM2655.new(port, baud) rescue nil
    
    server.start
  end
end
