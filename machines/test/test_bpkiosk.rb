require 'sinatra'
require 'active_record'
require 'minitest/autorun'
require 'national_patient_id'
require 'rack/test'
require 'lib/controller'
require 'lib/client'
require 'lib/reading'
require 'national_patient_id'

#require 'mock_bpmachine'
set :environment, :test
set :device, '/dev/ttyUSB0'
set :baud, 2400
set :title, 'BP Kiosk'
set :views, '../views'

db_config = {:adapter => 'sqlite3',
             :database => '/home/soyapi/src/pitt/bpkiosk/db/bpkiosk-test.db'}
ActiveRecord::Base.establish_connection(db_config)

class BPMachine < MiniTest::Mock
  @@current = nil
  
  def initialize(device=nil, baud=nil)
    super()
  end
  
  def self.current
    @@current
  end
  
  def self.current=(machine)
    @@current = machine
  end
  
  def self.last_reading
    []
  end
end

class TestBPKiosk < MiniTest::Unit::TestCase
  include Rack::Test::Methods
  
  def setup
    @bpmachine = BPMachine.new
    @browser = Rack::Test::Session.new(Rack::MockSession.new(Sinatra::Application))
  end

  def test_home
    BPMachine.stub(:current=, @bpmachine) do
      @browser.get '/'
      assert @browser.last_response.ok?
      assert @browser.last_response.body.include?('BP Kiosk'), 'should show title'
    end
  end
  
  def test_start
    @bpmachine.expect :start, nil
    BPMachine.stub(:current=, @bpmachine) do
      BPMachine.current = @bpmachine
      @bpmachine.expect :start, []
      @bpmachine.expect :read,  []
      @bpmachine.expect :last_reading, {:systolic => 123.5, :diastolic => 82.3, :pulse => 65.4}
    
      BPMachine.stub(:current, @bpmachine) do
        @browser.get '/start'
      end
      assert @browser.last_response.ok?, 'should open start page'
      assert @browser.last_response.body.include?('diastolic'), 'should show BP result'
    end
  end
  
  #@bpmachine.expect :stop,  nil
  def test_save_reading
    BPMachine.current = @bpmachine
    BPMachine.stub(:current=, @bpmachine) do
      BPMachine.current = @bpmachine
      @bpmachine.expect :last_reading, {:systolic => 123.5,
                                        :diastolic => 82.3,
                                        :pulse => 65.4}
      reading_count = Reading.count
      @browser.get '/save_reading'
      assert @browser.last_response.ok?
      assert_equal Reading.count, reading_count + 1
      assert @browser.last_response.body.include?('82.3'), @browser.last_response.body
    end
    
  end    
  
  def test_find_client
    @browser.post '/results', :client_number => '1000AA'
    assert @browser.last_response.body.include?('NOT found'), @browser.last_response.body
    
    client = Client.add
    @browser.get "/find_client?client_number=#{client.client_number}"
    assert @browser.last_response.body.include?("Client #{client.client_number} found"),
           @browser.last_response.body
  end
end
