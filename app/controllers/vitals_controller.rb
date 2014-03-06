require "rest-client"
require "socket"

class VitalsController < ApplicationController

  before_filter :check_login, :except => [:login, :logout, :authenticate, :verify_location, :query]
  
  before_filter :check_location, :except => [:login, :logout, :authenticate, :verify_location, :location, :query]    
  
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

  def void
    
    if params[:obs].class.to_s.downcase.strip == "array"
    
      params[:obs].each do |obs|
      
        res = RestClient.delete("http://#{@openmrslink}/ws/rest/v1/obs/#{obs}", {:content_type => :json, :Cookie => "JSESSIONID=#{cookies[:jsessionid]}", :accept => :json}) rescue nil
        
        if res.nil?
        
          flash[:error] = "Data void error!"
        
          redirect_to "/patient" and return
        
        end      
    
      end
    
    else
      res = RestClient.delete("http://#{@openmrslink}/ws/rest/v1/obs/#{params[:obs]}", {:content_type => :json, :Cookie => "JSESSIONID=#{cookies[:jsessionid]}", :accept => :json}) rescue nil
      
      if res.nil?
      
        flash[:error] = "Data void error!"
      
        redirect_to "/patient" and return
      
      end      
    
    end
    
    flash[:notice] = "Record voided!"
        
    redirect_to "/patient" and return
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
          
          @months[e.to_time.strftime("%Y-%m-%d").to_time.to_i * 1000] = e.to_time.strftime("%b/%y") if @months[e.to_time.strftime("%Y-%m-%d").to_time.to_i * 1000].nil?
          
          @readings[o["concept"]["display"]] = {} if @readings[o["concept"]["display"]].nil?
          
          @readings[o["concept"]["display"]][e.to_time.strftime("%Y-%m-%d").to_time.to_i * 1000] = (o["display"][o["concept"]["display"].strip.length + 1, o["display"].length]).strip.to_f
          
          @source[o["concept"]["display"]] = {} if @source[o["concept"]["display"]].nil?
          
          @source[o["concept"]["display"]][e.to_time.strftime("%b/%y")] = (o["display"][o["concept"]["display"].strip.length + 1, o["display"].length]).strip
          
          @encounters[e] = {} if @encounters[e].nil?; 
          
          @target[o["concept"]["display"]] = {} if @target[o["concept"]["display"]].nil?
          
          if @target[o["concept"]["display"]]["date"].nil?
          
             @target[o["concept"]["display"]]["date"] = e 
          
             @target[o["concept"]["display"]]["value"] = (o["display"][o["concept"]["display"].strip.length + 1, o["display"].length]).strip.to_f
             
             @target[o["concept"]["display"]]["uuid"] = o["uuid"]
                
          elsif @target[o["concept"]["display"]]["date"].to_time < e.to_time
            
             @target[o["concept"]["display"]]["date"] = e           
             
             @target[o["concept"]["display"]]["value"] = (o["display"][o["concept"]["display"].strip.length + 1, o["display"].length]).strip.strip.to_f
               
             @target[o["concept"]["display"]]["uuid"] = o["uuid"]
                       
          end
          
          @encounters[e][o["concept"]["display"]] = (o["display"][o["concept"]["display"].strip.length + 1, o["display"].length]).strip
          
        end
        
      end
 
    end 
    
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
    
    previous = {}
    
    @readings.each do |concept, members|
      
      next if presets[concept].nil?
      
      @order << concept
      
      previous[concept] = 0 if previous[concept].nil?
      
      @data[:labels].each{|month|        
         presets[concept]["data"] << (members[month].nil? ? previous[concept] : members[month])
         
        previous[concept] = members[month] if !members[month].nil?      
      }
      
      @data[:datasets] << (presets[concept].nil? ? 0 : presets[concept])
      
    end # rescue nil
    
    @presentation = {}
    
    i = 0
    @order.each{|o| 
      @presentation[o] = i
      i = i + 1
    }
    
    # raise @target.to_yaml
    
    render :layout => false
  end

  def new
  
    @params = params["fl"].strip.split(" ") rescue []
    
    @rules = YAML.load_file("#{Rails.root}/public/rules/vitals.yml")
        
    remote_port_is_open = port_open?(request.remote_host.strip, 3000, 10)
       
    if !remote_port_is_open 
      questions = {}
      
      @rules["questions"].each do |key, value|
      
        value.delete("equipment_url") if !value["equipment_url"].nil?
      
        questions[key] = value
      
      end
      
      @rules["questions"] = questions 
       
    end
       
    # raise @rules.to_yaml
       
    render "rules/rules", :layout => false
  end

  def create
    render :layout => false
  end

  def edit
    render :layout => false
  end

  def update
    fields = [
      "5088AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 
      "5087AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 
      "5085AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 
      "5086AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 
      "5242AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 
      "5089AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 
      "5090AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 
      "5092AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    ]
  
    # raise params.to_yaml
  
    query = ActiveSupport::OrderedHash.new
  
=begin
    query = {     
      "patient" => cookies[:current_patient],     
      "encounterDatetime" => (cookies[:date].to_date rescue Date.today).strftime("%Y-%m-%d"),     
      "location" => cookies[:location_name],     
      "encounterType" => params[:encounter_type],     
      "provider" => cookies[:user_person],     
      "obs" => []    
    }
=end 

    query["patient"] = cookies[:current_patient]     
    query["encounterDatetime"] = (cookies[:date].to_date rescue Date.today).strftime("%Y-%m-%d")     
    query["location"] = cookies[:location_name]     
    query["encounterType"] = params[:encounter_type]     
    query["provider"] = cookies[:user_person]     
    query["obs"] = [] 

    fields.each do |field|

      if !params[field].nil?
      
        hash = ActiveSupport::OrderedHash.new
        
        hash["concept"] = field
        hash["value"] = params[field]
        
        query["obs"] << hash
      
      end    
    
    end
    
    # raise query.to_json
    
    res = RestClient.post("http://#{@openmrslink}/ws/rest/v1/encounter", query.to_json, {:content_type => :json, :Cookie => "JSESSIONID=#{cookies[:jsessionid]}", :accept => :json}) #  rescue nil
    
    # raise res.inspect
    
    if res.nil?
    
      flash[:error] = "Data save error!"
    
      redirect_to "/patient" and return
    
    else 
    
      flash[:notice] = "Record saved!"
      
      redirect_to "/patient" and return
    
    end  
    
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
    
      cookies[:user_person] = json["results"][0]["person"]["uuid"]
    
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
    
    if !params[:name].nil?
    
        res = RestClient.get("http://#{@openmrslink}/ws/rest/v1/patient?q=#{params[:name].gsub(/\s/, "+")}&v=full", {:Cookie => "JSESSIONID=#{cookies[:jsessionid]}", :accept => :json}) # rescue nil
        
        result = {}
        
        if !res.nil?
        
          json = JSON.parse(res) rescue {}
        
          json["results"].each do |o|
          
            person = {
              :uuid => (o["uuid"] rescue nil),
              :name => (o["person"]["display"] rescue nil),
              :age => (o["person"]["age"] rescue nil),
              :estimated => (o["person"]["birthdateEstimated"] rescue nil),
              :identifier => (o["identifiers"].first["identifier"] rescue nil),
              :idtype => (o["identifiers"].first["identifierType"]["display"] rescue nil),
              :gender => (o["person"]["gender"] rescue nil),
              :village => (o["person"]["preferredAddress"]["cityVillage"] rescue nil)
            }
          
            result[o["uuid"]] = person
            
          end
            
        end 
        
        render :text => result.to_json and return
        
    elsif !params[:given_name].nil?
      
      search_given_name(params[:given_name]) and return     
     
    elsif !params[:family_name].nil?
      
      search_family_name(params[:family_name]) and return     
     
    elsif !params[:occupation].nil?
      
      search_occupation(params[:occupation]) and return     
     
    elsif !params[:religion].nil?
      
      search_religion(params[:religion]) and return     
     
    elsif !cookies[:region_of_residence].nil? and !cookies[:district_of_residence].nil? and !cookies[:ta_of_residence].nil? and !params[:village_of_residence].nil?
      
      search_village(cookies[:region_of_residence], cookies[:district_of_residence], cookies[:ta_of_residence], params[:village_of_residence]) and return     
     
    elsif !cookies[:region_of_residence].nil? and !cookies[:district_of_residence].nil? and !params[:ta_of_residence].nil?
      
      search_ta(cookies[:region_of_residence], cookies[:district_of_residence], params[:ta_of_residence]) and return     
     
    elsif !cookies[:region_of_residence].nil? and !params[:district_of_residence].nil?
      
      search_district(cookies[:region_of_residence], params[:district_of_residence]) and return     
     
    elsif !params[:region_of_residence].nil?
      
      search_region(params[:region_of_residence]) and return     
     
     
     
    elsif !cookies[:region_of_origin].nil? and !cookies[:district_of_origin].nil? and !cookies[:ta_of_origin].nil? and !params[:village_of_origin].nil?
      
      search_village(cookies[:region_of_origin], cookies[:district_of_origin], cookies[:ta_of_origin], params[:village_of_origin]) and return     
     
    elsif !cookies[:region_of_origin].nil? and !cookies[:district_of_origin].nil? and !params[:ta_of_origin].nil?
      
      search_ta(cookies[:region_of_origin], cookies[:district_of_origin], params[:ta_of_origin]) and return     
     
    elsif !cookies[:region_of_origin].nil? and !params[:district_of_origin].nil?
      
      search_district(cookies[:region_of_origin], params[:district_of_origin]) and return     
     
    elsif !params[:region_of_origin].nil?
      
      search_region(params[:region_of_origin]) and return     
     
    end
           
    render :text => ""       
  end

  def search_given_name(name)
    result = ["<li value='#{name}'>#{name}</li>"]
    
    render :text => result.join('')
  end
  
  def search_family_name(name)
    result = ["<li value='#{name}'>#{name}</li>"]
    
    render :text => result.join('')
  end
  
  def search_occupation(name)
    occupations = ["Housewife", "Policeman", "Soldier", "Business", "Student", "Other", "Farmer"]
    
    result = []
    
    occupations.sort.each do |occupation|
  
      result << "<li value='#{occupation}'>#{occupation}</li>" if (!name.blank? and occupation.downcase.match("^" + name.downcase.strip)) or name.blank?
    
    end
    
    render :text => result.join('')
  end
  
  def search_religion(name)
    religions = ["Presbyterian", "Catholic", "Jehovah's Witness", "Adventist", "Moslem", "Other"]
    
    result = []
    
    religions.sort.each do |religion|
  
      result << "<li value='#{religion}'>#{religion}</li>" if (!name.blank? and religion.downcase.match("^" + name.downcase.strip)) or name.blank?
    
    end
    
    render :text => result.join('')
  end
  
  def search_region(name)
    regions = YAML.load_file("#{Rails.root}/public/data/national.yml") rescue {}
    
    result = []
    
    regions.keys.sort.each do |region|
  
      result << "<li value='#{region}'>#{region}</li>" if (!name.blank? and region.downcase.match("^" + name.downcase.strip)) or name.blank?
    
    end
    
    render :text => result.join('')
  end
  
  def search_district(region, name)
    regions = YAML.load_file("#{Rails.root}/public/data/national.yml")[region] rescue {}
    
    result = []
    
    regions.keys.sort.each do |district|
  
      result << "<li value='#{district}'>#{district}</li>" if (!name.blank? and district.downcase.match("^" + name.downcase.strip)) or name.blank?
    
    end
    
    render :text => result.join('')
  end
  
  def search_ta(region, district, name)
    regions = YAML.load_file("#{Rails.root}/public/data/national.yml")[region][district] rescue {}
    
    result = []
    
    regions.keys.sort.each do |ta|
  
      result << "<li value='#{ta}'>#{ta}</li>" if (!name.blank? and ta.downcase.match("^" + name.downcase.strip)) or name.blank?
    
    end rescue nil
    
    render :text => result.join('')
  end
  
  def search_village(region, district, ta, name)
    regions = YAML.load_file("#{Rails.root}/public/data/national.yml")[region][district][ta] rescue {}
    
    result = []
    
    regions.keys.sort.each do |village|
  
      result << "<li value='#{village}'>#{village}</li>" if (!name.blank? and village.downcase.match("^" + name.downcase.strip)) or name.blank?
    
    end rescue nil
    
    render :text => result.join('')
  end
  
  def set_patient
    
    redirect_to "/search_by_name" if params[:patient].blank? and return
    
    cookies[:current_patient] = params[:patient]
    
    redirect_to "/patient" and return
    
  end
  
  def new_patient
    @rules = YAML.load_file("#{Rails.root}/public/rules/new_patient.yml") rescue nil
    
    render "rules/rules", :layout => false
  end
  
  def create_patient
  
    dob = nil
    estimated = ((params["person_birth_year"].to_s == "unknown" or 
          params["person_birth_month"].to_s == "unknown" or 
          params["person_birth_day"].to_s == "unknown") ? true : false)
    
    if !params["person_birth_year"].to_s.match(/unknown/i)
      
      if !params["person_birth_month"].to_s.match(/unknown/i)
      
        if !params["person_birth_day"].to_s.match(/unknown/i)
                  
          dob = "#{params["person_birth_year"]}-#{"%02d" % params["person_birth_month"].to_i}-#{"%02d" % params["person_birth_day"].to_i}"        
          
        else
        
          dob = "#{params["person_birth_year"]}-#{"%02d" % params["person_birth_month"].to_i}-15"
        
        end
      
      else
      
        dob = "#{params["person_birth_year"]}-07-15"
      
      end
      
    else
      dob = (Date.today - (params["age"].to_i rescue 0).year).strftime("%Y-07-15")
    end
  
    person = {
      "names" => [
        {
          "givenName" => (params["given_name"] rescue nil),
          "familyName" => (params["family_name"] rescue nil),
          "middleName" => (params["middle_name"] rescue nil),
          "familyName2" => (params["maiden_name"] rescue nil)
        }
      ],
      "addresses" => [
        {
          "cityVillage" => (params[:village_of_residence] rescue nil),
          "address2" => (params[:ta_of_residence] rescue nil),
          "stateProvince" => (params[:district_of_residence] rescue nil),
          "address3" => (params[:village_of_origin] rescue nil),
          "address4" => (params[:ta_of_origin] rescue nil),
          "address5" => (params[:district_of_origin] rescue nil)
        }
      ],
      "gender" => (params["gender"] rescue nil),
      "birthdate" => dob,
      "birthdateEstimated" => estimated
    }
    
    res = RestClient.post("http://#{@openmrslink}/ws/rest/v1/person", person.to_json, {:content_type => :json, :Cookie => "JSESSIONID=#{cookies[:jsessionid]}", :accept => :json}) rescue nil
    
    person_uuid = ""
    
    if !res.nil?
    
      json = JSON.parse(res) rescue {}
     
      person_uuid = json["uuid"]
    
      patient = {
        "person" => person_uuid,
        "identifiers" => [
          {
            "identifier" => Time.now.to_i.to_s,    # TODO: Need to add DDE identifier later
            "identifierType" => "d6bbcbff-7a56-4661-afa3-413e4c328d96",
            "location" => (cookies[:location] rescue "Unknown Location")
          }
        ]
      }
    
      res = RestClient.post("http://#{@openmrslink}/ws/rest/v1/patient", patient.to_json, {:content_type => :json, :Cookie => "JSESSIONID=#{cookies[:jsessionid]}", :accept => :json})  rescue nil
      
      if !res.nil?
      
        cookies[:current_patient] = person_uuid 
        
        flash[:notice] = "Patient Created"
        
        redirect_to "/patient" and return
      
      end
      
    end
       
    flash[:error] = "Patient Creation Failed!"
       
    redirect_to "/" and return
       
  end
  
  def query
    result = ""
    
    result = RestClient.get("http://#{request.remote_host.strip}:3000/#{params[:f]}?t=#{Time.now.to_i}") if !params[:f].nil?
    
    render :text => result.to_s
  end
  
  def query_json
    result = ""
    
    result = RestClient.get("http://#{request.remote_host.strip}:3000/#{params[:f]}?t=#{Time.now.to_i}") if !params[:f].nil?
    
    render :json => result
  end
  
  def readings
    @referrer = request.remote_host.strip
    render :layout => false
  end
  
  def read
    @referrer = request.remote_host.strip
    render :layout => false
  end
  
  def bp
    @referrer = request.remote_host.strip
    render :layout => false
  end
  
  def port_open?(ip, port, timeout)  
    start_time = Time.now  
    
    current_time = start_time  
    while (current_time - start_time) <= timeout  
      begin  
        TCPSocket.new(ip, port)
          
        return true          
      rescue Errno::ECONNREFUSED  
        sleep 0.1  
      end  
      
      current_time = Time.now  
    end  
    
    return false  
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
