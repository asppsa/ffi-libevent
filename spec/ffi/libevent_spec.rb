describe FFI::Libevent do

  describe '.supported_methods' do
    it "returns a list of symbols" do
      methods = FFI::Libevent.supported_methods
      expect(methods.length).to be > 0
      expect(methods).to all(be_a Symbol)
    end
  end
end
