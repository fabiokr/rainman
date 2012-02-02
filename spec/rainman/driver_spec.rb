require 'spec_helper'


describe "Rainman::Driver" do
  before do
    Rainman::Driver.instance_variable_set(:@all, [])
    @module = Module.new do
      def self.name
        'MissDaisy'
      end
    end
    @module.extend Rainman::Driver
    Object.send(:remove_const, :MissDaisy) if Object.const_defined?(:MissDaisy)
    Object.const_set(:MissDaisy, @module)
  end

  describe "::extended" do
    it "extends base with base" do
      m = Module.new
      m.should_receive(:extend).with(m)
      Rainman::Driver.extended(m)
    end
  end

  describe "::all" do
    it "returns an array of registered drivers" do
      Rainman::Driver.all.should == [@module]
    end
  end

  describe "#handlers" do
    it "returns an empty hash" do
      @module.handlers.should == {}
    end

    it "raises exception when accessing an unknown key" do
      expect { @module.handlers[:foo] }.to raise_error(Rainman::InvalidHandler)
    end

    it "raises exception when accessing a nil key" do
      expect { @module.handlers[nil] }.to raise_error(Rainman::NoHandler)
    end
  end

  describe "#with_handler" do
    before do
      @klass = Class.new do
        def hi; :hi_handler!; end
      end

      @module.const_set(:Bob, @klass)
      @module.send :register_handler, :bob, :class_name => @klass.to_s
      @module.send :define_action, :hi
      @module.set_current_handler :the_default_handler
    end

    it "should temporarily use the current handler" do
      res = @module.with_handler :bob do |driver|
        driver.hi
      end

      res.should == :hi_handler!

      @module.current_handler.should == :the_default_handler
    end

    it "should raise an error without a block" do
      expect { @module.with_handler(:bob) }.to raise_error(Rainman::MissingBlock)
    end
  end

  describe "#set_default_handler" do
    it "sets @default_handler" do
      @module.set_default_handler :blah
      @module.instance_variable_get(:@default_handler).should == :blah
    end
  end

  describe "#default_handler" do
    it "gets @default_handler" do
      expected = @module.instance_variable_get(:@default_handler)
      @module.default_handler.should eq(expected)
    end
  end

  describe "#included" do
    it "extends base with Forwardable" do
      klass = Class.new
      klass.should_receive(:extend).with(::Forwardable)
      klass.stub(:def_delegators)
      klass.send(:include, @module)
    end

    it "sets up delegation for singleton methods" do
      klass = Class.new
      klass.should_receive(:def_delegators).with(@module, *@module.singleton_methods)
      klass.send(:include, @module)
    end
  end

  describe "#handler_instances" do
    it "returns @handler_instances" do
      @module.send(:handler_instances).should == {}
      @module.instance_variable_set(:@handler_instances, { :foo => :test })
      @module.send(:handler_instances).should == { :foo => :test }
    end

    it "should call handler_setup if it exists" do
      module MissDaisy
        extend Rainman::Driver
        class WithSetup
          attr_reader :setup

          def setup_handler
            @setup = true
          end
        end

        class WithoutSetup
          attr_reader :setup
        end

        register_handler :with_setup
        register_handler :without_setup
        define_action :setup
      end

      MissDaisy.set_current_handler :with_setup
      MissDaisy.setup.should be_true
      MissDaisy.set_current_handler :without_setup
      MissDaisy.setup.should_not be_true
    end
  end

  describe "#set_current_handler" do
    it "sets @current_handler" do
      @module.set_current_handler :blah
      @module.instance_variable_get(:@current_handler).should == :blah
      @module.set_current_handler :other
      @module.instance_variable_get(:@current_handler).should == :other
    end
  end

  describe "#current_handler_instance" do
    before do
      @class = Class.new
      @klass = @class.new
      @module.handlers[:abc] = @class
      @module.send(:set_current_handler, :abc)
    end

    it "returns the handler instance" do
      @module.send(:handler_instances).merge!(:abc => @klass)
      @module.send(:current_handler_instance).should == @klass
    end

    it "sets the handler instance" do
      @module.handlers[:abc] = @class
      @class.should_receive(:new).and_return(@klass)
      @module.send(:current_handler_instance).should be_a(@class)
    end
  end

  describe "#current_handler" do
    it "returns @current_handler if set" do
      @module.instance_variable_set(:@current_handler, :blah)
      @module.send(:current_handler).should == :blah
    end

    it "returns @default_handler if @current_handler is not set" do
      @module.instance_variable_set(:@current_handler, nil)
      @module.instance_variable_set(:@default_handler, :blah)
      @module.send(:current_handler).should == :blah
    end
  end

  describe "#register_handler" do
    before do
      @bob = Class.new do
        def self.name; 'Bob'; end
      end
      @module.const_set(:Bob, @bob)
    end

    it "adds the handler to handlers" do
      @module.send(:register_handler, :bob)
      @module.handlers.should have_key(:bob)
      @module.handlers[:bob].should == @bob
    end

    describe ":class_name option" do
      it "allows a string" do
        @module.send(:register_handler, :bob, :class_name => 'MissDaisy::Bob')
        @module.handlers.should have_key(:bob)
        @module.handlers[:bob].should == @bob
      end

      it "allows a constant" do
        @module.send(:register_handler, :bob, :class_name => MissDaisy::Bob)
        @module.handlers.should have_key(:bob)
        @module.handlers[:bob].should == @bob
      end
    end
  end

  describe "#define_action" do
    before do
      @klass = Class.new do
        def self.name; 'Bob'; end
        def profile; :bob_is_cool; end
        def blah; :bob_blah; end
      end

      @module.const_set(:Bob, @klass)
      @module.send :register_handler, :bob, :class_name => @klass.to_s
      @module.set_default_handler :bob
    end

    it "creates the method" do
      @module.should_not respond_to(:blah)
      @module.send(:define_action, :blah)
      @module.should respond_to(:blah)

      @module.blah.should == :bob_blah
    end

    it "aliases the method if :alias is supplied" do
      @module.should_not respond_to(:blah)
      @module.send(:define_action, :blah, :alias => :superBLAH)
      @module.should respond_to(:blah)
      @module.should respond_to(:superBLAH)
      @module.superBLAH.should == :bob_blah
    end

    it "delegates the method if :delegate_to is supplied" do
      @module.send(:define_action, :description, :delegate_to => :profile)
      @module.should respond_to(:description)
      @module.description.should == :bob_is_cool
    end
  end

  describe "#create_method" do
    it "raises AlreadyImplemented if the method has been defined" do
      @module.instance_eval do
        def blah; end
      end

      expect do
        @module.send(:create_method, :blah)
      end.to raise_error(Rainman::AlreadyImplemented)
    end

    it "adds the method" do
      @module.should_not respond_to(:blah)
      @module.send(:create_method, :blah, lambda { :hi })
      @module.should respond_to(:blah)
      @module.blah.should == :hi
    end
  end

  describe "#namespace" do
    def create_ns_class(name, base)
      klass = Class.new do
        def hi; self.class end
      end

      set_const(base, name.to_s.camelize.to_sym, klass)
    end

    def set_const(base, name, const)
      base.send(:remove_const, name) if base.const_defined?(name)
      base.const_set(name, const)
    end

    before do
      create_ns_class :abc, @module
      create_ns_class :xyz, @module
      create_ns_class :bob, @module::Abc
      create_ns_class :bob, @module::Xyz

      @module.send(:register_handler, :abc)
      @module.send(:register_handler, :xyz)
      @module.set_default_handler :abc
      @module.send(:namespace, :bob) do
        define_action :hi
      end
    end

    it "raises exception calling a method that isn't registered" do
      expect { @module.bob.bye }.to raise_error(NoMethodError)
    end

    it "calls the namespaced method if it is registered" do
      @module.bob.hi.should == @module::Abc::Bob
    end

    it "uses the right handler" do
      [:abc, :xyz].each do |h|
        @module.with_handler(h) do |handler|
          handler.bob.hi.should == "MissDaisy::#{h.to_s.capitalize}::Bob".constantize
        end
      end
    end
  end
end
