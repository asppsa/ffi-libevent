describe FFI::Libevent::Timeval do

  shared_examples :seconds do |method|
    it "creates a timeval with the given number of seconds" do
      expect(described_class.send(method,5).seconds).to eq 5
      expect(described_class.send(method,5).microseconds).to eq 0
    end
  end

  shared_examples :microseconds do |method|
    it "creates a timeval with the given number of microseconds" do
      expect(described_class.send(method,5).microseconds).to eq 5
      expect(described_class.send(method,5).seconds).to eq 0
    end
  end
  
  describe ".seconds" do
    include_examples :seconds, :seconds
  end

  describe ".s" do
    include_examples :seconds, :s
  end

  describe ".microseconds" do
    include_examples :microseconds, :microseconds
  end

  describe ".us" do
    include_examples :microseconds, :us
  end

  describe ".useconds" do
    include_examples :microseconds, :useconds
  end
end
