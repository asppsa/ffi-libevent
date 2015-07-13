describe FFI::Libevent::Base do
  describe '.new' do
    shared_examples :returns do |obj|
      it "returns an object of the correct class" do
        expect(obj).to be_a described_class
      end
    end
    
    context "without args" do
      include_examples :returns, described_class.new
    end

    context "with an :avoid_method option" do
      include_examples :returns, described_class.new(:avoid_method => :epoll)
    end
    
    context "with an :avoid_methods option" do
      include_examples :returns, described_class.new(:avoid_methods => [:epoll, :select])
    end

    context "with a :require_features option" do
      include_examples :returns, described_class.new(:require_features => FFI::Libevent::FEATURE_O1 | FFI::Libevent::FEATURE_ET)
    end

    context "with incompatible :require_features options" do
      it "raises an error" do
        expect{ described_class.new(:require_features => FFI::Libevent::FEATURE_O1 | FFI::Libevent::FEATURE_FDS) }.
          to raise_error RuntimeError
      end
    end

    context "with :flags as ints" do
      include_examples :returns, described_class.new(:flags => FFI::Libevent::FLAG_NOLOCK | FFI::Libevent::FLAG_EPOLL_USE_CHANGELIST)
    end

    context "with :flags as symbols" do
      include_examples :returns, described_class.new(:flags => :nolock)
    end
  end

  context "with an initialized object" do

    subject!{ described_class.new }

    describe "#base_method" do
      it "returns a symbol" do
        expect(subject.base_method).to be_a Symbol
        expect(%w{select poll epoll kqueue devpoll evport win32}).to include subject.base_method.to_s
      end
    end

    describe "#loop!" do
      context "without flags" do
        it "returns 1 when there are no events" do
          expect(subject.loop!).to eq 1
        end
      end

      context "with the EVLOOP_NO_EXIT_ON_EMPTY flag" do
        it "returns 1 when there are no events" do
          expect(subject.loop! FFI::Libevent::EVLOOP_NO_EXIT_ON_EMPTY).to eq 1
        end
      end
    end

    describe "#dispatch!" do
      it "returns 1 when there are no events" do
        expect(subject.dispatch!).to eq 1
      end
    end

    describe "#loopexit!" do
      context "when no loop is running" do
        it "does nothing" do
          expect{ subject.loopexit! }.not_to raise_error
        end
      end
    end

    describe "#loopbreak!" do
      context "when no loop is running" do
        it "does nothing" do
          expect{ subject.loopbreak! }.not_to raise_error
        end
      end
    end

    describe "#got_exit?" do
      context "when loop has never run" do
        it "returns false" do
          expect(subject.got_exit?).to be false
        end
      end
    end

    describe "#got_break?" do
      context "when loop has never run" do
        it "returns false" do
          expect(subject.got_break?).to be false
        end
      end
    end
  end

  context "deleting" do
    it "removes the object from the object space" do
      # Create a base objecrt
      base = described_class.new
      id = base.object_id

      # Delete the object and run garbage collector
      base = nil
      ObjectSpace.garbage_collect

      # Check that the object is no longer in the object space
      ObjectSpace.each_object(described_class) do |base|
        expect(base.object_id).not_to eq id
      end
    end
  end
end

