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

  describe ".ms" do
    it "creates a timeval with the given number of milliseconds" do
      expect(described_class.ms(5).microseconds).to eq 5000
      expect(described_class.ms(5).seconds).to eq 0
    end
  end

  describe ".m" do
    it "creates a timeval with the given number of minutes" do
      expect(described_class.m(5).seconds).to eq 300
      expect(described_class.m(5).microseconds).to eq 0
    end
  end

  describe ".h" do
    it "creates a timeval with the given number of hours" do
      expect(described_class.h(1).seconds).to eq 3600
      expect(described_class.h(1).microseconds).to eq 0
    end
  end

end
