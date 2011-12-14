require 'spec_helper'

describe Rainman::Driver do
  describe "#register_handler" do

    module Mod1
      extend Rainman::Driver
      class Vern
      end

      class Uhoh
      end

      register_handler(:vern)
      register_handler(:uhoh) do |config|
        config[:hot] = true
      end

      define_action :my_method do
      end
    end


    it "should make Mod1 a Driver" do
      Mod1.should     be_a(Rainman::Driver)
      Mod1.should_not be_a(Rainman::Handler)
    end

    it "should make Mod1::Vern a Handler" do
      Mod1::Vern.should     be_a(Rainman::Handler)
      Mod1::Vern.should_not be_a(Rainman::Driver)
    end

    it "should raise an error for an unknow Handler" do
      expect {
        module Mod2
          extend Rainman::Driver
          register_handler(:what)
        end
      }.to raise_error("Unknown handler 'Mod2::What'")
    end

    it "should yield a config" do
      Mod1::Vern.config.should eql({})
      Mod1::Uhoh.config.should eql({ :hot => true})
    end

    it "should keep track of it's handlers" do
      Mod1::handlers.should include(:vern, :uhoh)
    end
  end

  describe "#define_action" do
    it "should define a method" do
      Mod1.should respond_to(:my_method)
    end
  end

  describe "#add_handler" do
    before(:each) do
      module Mod3
        extend Rainman::Driver
        class Blah
        end
      end

      Mod3::instance_variable_set('@handlers', [])
    end

    it "should add a handler" do
      Mod3::handlers.should be_empty
      Mod3.send(:add_handler, :blah)
      Mod3::handlers.should include(:blah)
    end

    it "should raise an error on duplicate handlers" do
      Mod3::handlers.should be_empty
      Mod3.send(:add_handler, :blah)
      expect {
        Mod3.send(:add_handler, :blah)
      }.to raise_error("Handler already registered 'Mod3::Blah'")
    end
  end

end
