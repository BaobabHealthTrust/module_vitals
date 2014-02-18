require "rest-client"

class VitalsController < ApplicationController

  before_filter :check_login, :except => [:login, :logout, :authenticate, :verify_location]
  
  before_filter :check_location, :except => [:login, :logout, :authenticate, :verify_location, :location]    
  
  def index    
    render :layout => false
  end

  def overview
    # (cookies[:date].to_date rescue Date.today)
    
    @types = ["Vitals"]
    @me = {"Vitals" => "-"}
    @today = {"Vitals" => "-"} 
    @year = {"Vitals" => "-"} 
    @ever = {"Vitals" => "-"}
    
    res = RestClient.get("http://#{@openmrslink}/ws/rest/v1/encountertype?q=vitals", {:Cookie => "JSESSIONID=#{cookies[:jsessionid]}", :accept => :json})  rescue nil
    
    if !res.nil?
    
      json = JSON.parse(res) rescue {}
    
      cookies[:encounter_vitals] = json["results"][0]["uuid"] rescue nil
    
    else
    
      flash[:error] = "Logged out!"
    
      redirect_to "/logout" and return
    
    end  
    
    render :layout => false
  end

  def search_by_npid
    res = RestClient.get("http://#{@openmrslink}/ws/rest/v1/patient?q=#{params[:identifier]}", {:Cookie => "JSESSIONID=#{cookies[:jsessionid]}", :accept => :json}) rescue nil
    
    if res.nil?
    
      flash[:error] = "No patient with that identifier found!"
    
      redirect_to "/" and return
    
    else 
    
      json = JSON.parse(res) rescue {}
    
      cookies[:current_patient] = json["results"][0]["uuid"] rescue nil
    
      redirect_to "/patient" and return
    
    end  
    
    render :layout => false    
  end

  def patient
    @json = {}
    
    redirect_to "/" and return if cookies[:current_patient].nil?
    
    res = RestClient.get("http://#{@openmrslink}/ws/rest/v1/patient/#{cookies[:current_patient]}", {:Cookie => "JSESSIONID=#{cookies[:jsessionid]}", :accept => :json}) rescue nil
    
    if res.nil?
    
      flash[:error] = "Patient not found assumed not authorised!"
    
      redirect_to "/logout" and return
    
    else     
      @json = JSON.parse(res) rescue {}    
    end  
    
    @encounters = {}
    
    encs = RestClient.get("http://#{@openmrslink}/ws/rest/v1/encounter?patient=#{cookies[:current_patient]}&encountertypes=#{cookies[:encounter_vitals]}&v=full&enddate=#{(cookies[:date].to_date rescue Date.today).strftime("%Y-%m-%d")}&startdate=#{((cookies[:date].to_date rescue Date.today) - 3.year).strftime("%Y-%m-%d")}", {:Cookie => "JSESSIONID=#{cookies[:jsessionid]}", :accept => :json}) # rescue nil
    
    @target = {}
    
    @source = {}
    
    @months = {}
    
    @readings = {}
    
    if !encs.nil?    
      jsonenc = JSON.parse(encs) rescue {}   
      
      jsonenc["results"].each do |obs|
      
        obs["obs"].each do |o| 
        
          e = o["obsDatetime"].to_time.strftime("%Y-%m-%d %H:%M"); 
          
          @months[e.to_time.strftime("%Y-%m-01").to_time.to_i * 1000] = e.to_time.strftime("%b/%y") if @months[e.to_time.strftime("%Y-%m-01").to_time.to_i * 1000].nil?
          
          @readings[o["concept"]["display"]] = {} if @readings[o["concept"]["display"]].nil?
          
          @readings[o["concept"]["display"]][e.to_time.strftime("%Y-%m-01").to_time.to_i * 1000] = (o["display"][o["concept"]["display"].strip.length + 1, o["display"].length]).strip.to_f
          
          @source[o["concept"]["display"]] = {} if @source[o["concept"]["display"]].nil?
          
          @source[o["concept"]["display"]][e.to_time.strftime("%b/%y")] = (o["display"][o["concept"]["display"].strip.length + 1, o["display"].length]).strip
          
          @encounters[e] = {} if @encounters[e].nil?; 
          
          @target[o["concept"]["display"]] = {} if @target[o["concept"]["display"]].nil?
          
          if @target[o["concept"]["display"]]["date"].nil?
          
             @target[o["concept"]["display"]]["date"] = e 
          
             @target[o["concept"]["display"]]["value"] = (o["display"][o["concept"]["display"].strip.length + 1, o["display"].length]).strip.to_f
                
          elsif @target[o["concept"]["display"]]["date"].to_time < e.to_time
            
             @target[o["concept"]["display"]]["date"] = e           
             
             @target[o["concept"]["display"]]["value"] = (o["display"][o["concept"]["display"].strip.length + 1, o["display"].length]).strip.strip.to_f
                      
          end
          
          @encounters[e][o["concept"]["display"]] = (o["display"][o["concept"]["display"].strip.length + 1, o["display"].length]).strip
          
        end
        
      end
 
    end 
    
    # raise @data.to_yaml
    
    meters = (@target["Height (cm)"]["value"].to_f / 100.0) rescue 0
    
    bmi = (@target["Weight (kg)"]["value"].to_f / (meters * meters)).round(1) rescue "-"
    
    @target["BMI"] = bmi
    
    @data = {
      :labels => [],
      :datasets => []
    }
    
    @months.sort.each{|index, month|
       @data[:labels] << index
    }
    
    presets = {
      "Respiratory rate" => {
        "color" => "#b76f43",
				"data" => []
      }, 
      "Temperature (C)" => {
        "color" => "#4874d7",
				"data" => []
      }, 
      "SYSTOLIC BLOOD PRESSURE" => {
        "color" => "#d78e48",
				"data" => []
      }, 
      "DIASTOLIC BLOOD PRESSURE" => {
        "color" => "#e06cd4",
				"data" => []
      }, 
      "Weight (kg)" => {
				"color" => "#c00",
				"data" => []
      }, 
      "Height (cm)" => {
        "color" => "#4b6458",
				"data" => []
      }, 
      "Blood oxygen saturation" => {
        "color" => "#87b29f",
				"data" => []
      }, 
      "Pulse" => {
        "color" => "#49a7a1",
				"data" => []
      }
    }
    
    @order = []
    
    @readings.each do |concept, members|
      
      @order << concept
      
      @data[:labels].each{|month|        
         presets[concept]["data"] << (members[month])
      }
      
      @data[:datasets] << presets[concept]
      
    end
    
    @presentation = {}
    
    i = 0
    @order.each{|o| 
      @presentation[o] = i
      i = i + 1
    }
    
    # raise @data.to_yaml
    
    render :layout => false
  end

  def new
  
    @params = params["fl"].strip.split(" ") rescue []
    
    @equipment = YAML.load_file("#{Rails.root}/config/equipment.yml")
  
    @rules = YAML.load_file("#{Rails.root}/public/rules/vitals.yml")
        
    render "rules/rules", :layout => false
  end

  def create
    render :layout => false
  end

  def edit
    render :layout => false
  end

  def update
    render :layout => false
  end

  def login  
    @rules = YAML.load_file("#{Rails.root}/public/rules/login.yml") rescue nil
    
    render "rules/rules", :layout => false
  end
  
  def authenticate
    
    link = YAML.load_file("#{Rails.root}/config/application.yml")["#{Rails.env}"]["openmrs_url"] rescue nil
    
    if link.nil?
       flash[:error] = "Connection to OpenMRS Server Failed!"
       
       redirect_to "/login" and return
    end
    
    result = RestClient.get("http://#{params[:username]}:#{params[:password]}@#{link}/ws/rest/v1/session", {:accept => :json})
    
    json = JSON.parse(result) rescue {}
    
    if json["authenticated"]
      
      cookies[:jsessionid] = json["sessionId"] 
       
      res = RestClient.get("http://#{link}/ws/rest/v1/user?q=#{params[:username]}&v=full", {:Cookie => "JSESSIONID=#{json["sessionId"]}", :accept => :json})
      
      json = JSON.parse(res) rescue {}
    
      cookies[:user_uuid] = json["results"][0]["uuid"] # rescue nil
      
      cookies[:fullname] = json["results"][0]["person"]["display"] # rescue nil
      
      cookies[:username] = json["results"][0]["display"] # rescue nil

    
      redirect_to "#{cookies[:src]}" and return
      
    else
    
      flash[:error] = "Wrong username or password!"
    
      redirect_to "/login" and return
    
    end
    
  end
  
  def location  
    @rules = YAML.load_file("#{Rails.root}/public/rules/location.yml") rescue nil
    
    render "rules/rules", :layout => false
  end
  
  def verify_location
  
    link = YAML.load_file("#{Rails.root}/config/application.yml")["#{Rails.env}"]["openmrs_url"] rescue nil
  
    if link.nil?
       flash[:error] = "Connection to OpenMRS Server Failed!"
       
       redirect_to "/logout" and return
    end
    
    res = RestClient.get("http://#{link}/ws/rest/v1/location/#{params[:location]}?v=full", {:Cookie => "JSESSIONID=#{cookies[:jsessionid]}", :accept => :json}) rescue nil
    
    if res.nil?
    
      flash[:error] = "Location not valid!"
    
      redirect_to "/location" and return
    
    else 
    
      json = JSON.parse(res) rescue {}
    
      cookies[:parent_location] = json["parentLocation"]["display"] rescue nil
      
      cookies[:location_name] = json["display"] rescue nil
      
      cookies[:location] = json["uuid"] rescue nil
    
      redirect_to "#{cookies[:src]}" and return if !cookies[:src].match(/location/)
      
      redirect_to "/" and return
    
    end
    
  end
  
  def logout
  
      cookies.delete :jsessionid
      
      cookies.delete :user_uuid
      
      cookies.delete :fullname
      
      cookies.delete :username
      
      cookies.delete :location_name
      
      cookies.delete :location
      
      cookies.delete :current_patient
  
      flash[:notice] = "Logged out!"
    
      redirect_to "/login" and return
    
  end
  
  def change_date
    render :layout => false
  end
  
  def set_date
    cookies[:date] = params[:date] rescue Date.today.strftime("%Y-%m-%d")
    
    redirect_to "/" and return
  end
  
  def reset_date
    cookies[:date] = Date.today.strftime("%Y-%m-%d")
    
    redirect_to "/" and return
  end
  
  def search_by_name
    render :layout => false
  end

  def search
    
    res = RestClient.get("http://#{@openmrslink}/ws/rest/v1/patient?q=#{params[:name].gsub(/\s/, "+")}&v=full", {:Cookie => "JSESSIONID=#{cookies[:jsessionid]}", :accept => :json}) # rescue nil
    
    result = {}
    
    if !res.nil?
    
      json = JSON.parse(res) rescue {}
    
      json["results"].each do |o|
      
        person = {
          :uuid => o["uuid"],
          :name => o["person"]["display"],
          :age => o["person"]["age"],
          :estimated => o["person"]["birthdateEstimated"],
          :identifier => o["identifiers"].first["identifier"],
          :idtype => o["identifiers"].first["identifierType"]["display"],
          :gender => o["person"]["gender"],
          :village => o["person"]["preferredAddress"]["cityVillage"]
        }
      
        result[o["uuid"]] = person
        
      end
        
      # raise result.inspect    
    
      # raise result.to_yaml
    
    end  
       
    render :text => result.to_json 
  end
  
  def set_patient
    
    redirect_to "/search_by_name" if params[:patient].blank? and return
    
    cookies[:current_patient] = params[:patient]
    
    redirect_to "/patient" and return
    
  end
  
protected
  
  def check_login
    cookies[:src] = request.path
  
    @openmrslink = YAML.load_file("#{Rails.root}/config/application.yml")["#{Rails.env}"]["openmrs_url"] rescue nil
    
    redirect_to "/login" if cookies[:jsessionid].nil?
  end

  def check_location
  
    redirect_to "/location" if cookies[:location].nil?
  
  end

end
