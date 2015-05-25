describe FFI::Libevent::EvBuffer do

  shared_examples :creates_new do
    it "creates an empty buffer" do
      expect(evbuffer).to be_a described_class
      expect(evbuffer.length).to eq 0
    end
  end

  describe '.new' do
    let (:evbuffer){ described_class.new }

    include_examples :creates_new
  end

  describe '.with_lock' do
    context 'without a lock parameter' do
      let (:evbuffer){ described_class.with_lock }

      include_examples :creates_new
    end

    pending 'with a lock parameter'
  end

  describe '#enable_locking!' do
    subject{ described_class.new }

    it "returns nil" do
      expect(subject.enable_locking!).to be_nil
    end
  end

  describe '#locked' do
    subject{ described_class.new }

    it "executes the block" do
      called = false
      subject.locked{ called = true }
      expect(called).to be true
    end
  end

  describe '#length' do
    subject{ described_class.new }

    it "returns an integer" do
      expect(subject.length).to be_an Integer
    end

    it "returns the number of bytes in the buffer" do
      expect(subject.length).to eq 0
      subject.add "test"
      expect(subject.length).to eq 4
    end
  end

  describe '#continguous_space' do
    subject{ described_class.new }

    it "returns an integer" do
      expect(subject.contiguous_space).to be_an Integer
    end

    it "always returns a number less than or equal to length" do
      expect(subject.contiguous_space).to eq 0
      1000.times do
        subject.add "test"
        expect(subject.contiguous_space).to be <= subject.length
      end
    end
  end

  describe '#add' do
    subject{ described_class.new }

    context "with a string" do
      it "adds the entire string" do
        subject.add "test"
        expect(subject.length).to eq 4
      end
    end

    context "with a string and a length" do
      it "adds the first n bytes of the string" do
        subject.add 'testing 1 2 3', 4
        expect(subject.length).to eq 4
      end
    end

    context "with a memory pointer and a length" do
      it "adds the first n bytes from the memory" do
        ptr = FFI::MemoryPointer.new 4
        ptr.write_string "test"
        subject.add ptr, 4
        expect(subject.length).to eq 4
      end
    end

    context "with another evbuffer" do
      let(:other){ described_class.new }

      it "moves the bytes from the other buffer" do
        other.add "test"
        subject.add other
        expect(subject.length).to eq 4
        expect(other.length).to eq 0
      end
    end
  end

  describe '#remove' do
    subject{ described_class.new }

    context "with an integer" do
      it "removes that many characters from the front and returns them as a string" do
        subject.add "testing Testing testing blah"
        expect(subject.remove 7).to eq "testing"
      end
    end

    context "with a memory pointer and a length" do
      it "removes that many characters to the memory" do
        mem = FFI::MemoryPointer.new(10)
        subject.add "bla"
        expect(subject.remove mem, 4).to eq 3
        expect(mem.read_string(3)).to eq "bla"
      end
    end

    context "with another evbuffer" do
      let(:other){ described_class.new }

      it "writes a given number of bytes into the other buffer" do
        subject.add "hello 1 2 3"
        expect(other.length).to eq 0

        subject.remove other, 5
        expect(other.length).to eq 5
        expect(subject.length).to eq("hello 1 2 3".length - 5)
      end

      it "writes bytes from the front of the buffer to the end of the other buffer" do
        subject.add "hello 1 2 3"
        other.add "world "

        subject.remove other, 5

        # Check the left-over bytes
        expect(subject.remove 6).to eq " 1 2 3"
        expect(other.length).to eq 11
        expect(other.remove 11).to eq "world hello"
      end
    end
  end

  describe '#expand!' do
    subject{ described_class.new }

    it "increases the length of the buffer" do
      expect(subject.length).to eq 0
      subject.expand! 10
      expect(subject.length).to eq 0
    end

    it "doesn't bother to zero the memory" do
      subject.expand! 10
      expect(subject.remove 10).not_to eq("\0" * 10)
    end
  end

  describe "prepend" do
    subject{ described_class.new }

    context "with a string" do
      it "adds the string to the start of the buffer" do
        subject.add "test"
        subject.prepend "this is a "
        expect(subject.length).to eq 14
        expect(subject.remove 14).to eq "this is a test"
      end
    end
  end

  describe "pullup!" do
    context "with a parameter" do
      it "returns a pointer to a portion of memory" do
        subject.add "this is a test"
        mem = subject.pullup!(7)
        expect(mem).to respond_to :read_string
        expect(mem.read_string(7)).to eq "this is"
      end
    end

    context "without a parameter" do
      it "returns a pointer to the entire buffer" do
        str = "this is a test"
        subject.add str
        mem = subject.pullup!
        expect(mem.read_string(str.length)).to eq str
      end

      it "makes the entire buffer contiguous" do
        # This should create some non-contiguous spaces in memory
        1000.times do
          subject.add("t"*1000)
        end

        expect(subject.length).to be > subject.contiguous_space

        subject.pullup!
        expect(subject.length).to eq subject.contiguous_space
      end
    end
  end

  describe "#drain" do
    subject{ described_class.new }

    it "removes bytes from the front of the buffer" do
      subject.add "testing 1 2 3"
      subject.drain 4
      expect(subject.remove 3).to eq 'ing'
    end
  end

  describe "#copyout" do
    subject{ described_class.new }

    context "with an Integer" do
      it "returns a string" do
        subject.add "testing"
        expect(subject.copyout(4)).to eq "test"
        expect(subject.copyout(10)).to eq "testing"
      end
    end

    context "with a pointer" do
      it "returns the number of bytes copied" do
        ptr = FFI::MemoryPointer.new(10)
        subject.add "testing"
        expect(subject.copyout(ptr, 4)).to eq 4
        expect(subject.copyout(ptr, 10)).to eq 7
      end

      it "places a copy of the buffer's contents into the memory" do
        ptr = FFI::MemoryPointer.new(10)
        subject.add "this is a a test"
        len = subject.copyout(ptr, 4)
        expect(ptr.read_string(len)).to eq "this"
      end
    end
  end

  describe '#read_line' do
    subject{ described_class.new }

    shared_examples :reads_a_line do
      before do
        subject.add str
      end

      it "returns a string" do
        expect(subject.read_line(style)).to be_a String
      end

      it "returns the contents of the string up to the first carriage return" do
        str.each_line do |line|
          expect(subject.read_line(style)).to eq line.chomp
        end
      end

      it "returns nil when there are no more lines" do
        str.lines.length.times do
          subject.read_line(style)
        end

        expect(subject.read_line(style)).to be_nil
      end
    end

    context "reading text with carriage returns" do
      let(:str){ "this is a test\r\nthis is line 2\r\n" }

      context "using CRLF style" do
        let(:style) { :crlf }

        include_examples :reads_a_line
      end

      context "using CRLF-strict style" do
        let(:style) { :crlf_strict }

        include_examples :reads_a_line
      end
    end

    context "reading text with line feeds" do
      let(:str){ "this is a test\nthis is line 2\n" }

      context "using CRLF style" do
        let(:style) { :crlf }

        include_examples :reads_a_line
      end

      context "using LF style" do
        let(:style) { :lf }

        include_examples :reads_a_line
      end
    end
  end

  describe '#each_line' do
    subject{ described_class.new }

    let(:str){ "This is a test\nTesting 1 2 3\n" }

    before do
      subject.add str
    end

    context "with a block" do
      it "yields each line to the block" do
        lines = []
        subject.each_line do |line|
          lines.push line
        end

        expect(lines.length).to eq str.lines.length
        expect(lines).to contain_exactly(*str.lines.map(&:chomp))
      end
    end

    context "without a block" do
      it "returns an enumerator that can be used to iterate over the lines" do
        str_lines = str.lines.map(&:chomp)
        evb_lines = subject.each_line
        equals = evb_lines.zip(str_lines).map do |a,b|
          a == b
        end
        expect(equals).to all(be true)
      end
    end
  end
end
