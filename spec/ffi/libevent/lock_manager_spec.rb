describe FFI::Libevent::LockManager do
  subject{ described_class.new }

  describe '#lock_alloc' do
    context "with 0 param" do
      it "returns an integer" do
        expect(subject.lock_alloc(0)).to be_a Integer
      end

      it "returns a number that references a Mutex object" do
        locks = subject.instance_variable_get(:@locks)
        id = subject.lock_alloc(0)

        expect(locks[id]).to be_a Mutex
      end
    end

    context "with FFI::Libevent::LOCKTYPE_RECURSIVE param" do
      it "returns an integer" do
        expect(subject.lock_alloc(FFI::Libevent::LOCKTYPE_RECURSIVE)).to be_a Integer        
      end

      it "returns a number that references a RecursiveLock" do
        locks = subject.instance_variable_get(:@locks)
        id = subject.lock_alloc(FFI::Libevent::LOCKTYPE_RECURSIVE)

        expect(locks[id]).to be_a FFI::Libevent::LockManager::RecursiveLock
      end
    end
  end

  describe "#lock_free" do
    shared_examples :frees_lock do
      let!(:id){ subject.lock_alloc(mode) }
      let(:locks){ subject.instance_variable_get(:@locks) }

      it "removes the lock" do
        expect(locks[id]).not_to be_nil
        subject.lock_free(FFI::Pointer.new(id), nil)
        expect(locks[id]).to be_nil
      end
    end

    context "normal lock" do
      let(:mode){ 0 }
      include_examples :frees_lock
    end

    context "recursive lock" do
      let(:mode){ FFI::Libevent::LOCKTYPE_RECURSIVE }
      include_examples :frees_lock
    end
  end

  describe "#lock / #unlock" do
    shared_examples :serialises do
      it "serialises concurrent operations" do
        id = subject.lock_alloc(mode)

        x = ""
        
        Thread.new do
          ptr = FFI::Pointer.new(id)
          subject.lock(0, ptr)
          sleep 0.2
          x << '1'
          subject.unlock(0, ptr)
        end
        sleep 0.1
        ptr = FFI::Pointer.new(id)
        subject.lock(0, ptr)
        x << '2'
        subject.unlock(0, ptr)
        expect(x).to eq '12'
      end
    end

    shared_examples :returns do
      context "when able to lock" do
        let!(:id){ subject.lock_alloc(mode) }

        it "returns zero" do
          ptr = FFI::Pointer.new(id)
          expect(subject.lock(0, ptr)).to eq 0
        end
      end

      context "when lock is invalid" do
        it "returns nonzero" do
          ptr = FFI::Pointer.new(SecureRandom.random_number(1000))
          expect(subject.lock(0, ptr)).not_to eq 0
        end
      end

      context "when trying on a locked pointer" do
        let!(:id){ subject.lock_alloc(mode) }

        it "returns nonzero" do
          ptr = FFI::Pointer.new(id)
          Thread.new do
            subject.lock(0, ptr)
            sleep 1
          end
          
          sleep 0.2
          expect(subject.lock(FFI::Libevent::EVTHREAD_TRY, ptr)).not_to eq 0
        end
      end
    end

    context "normal lock" do
      let(:mode){ 0 }
      include_examples :serialises
      include_examples :returns
    end

    context "recursive lock" do
      let(:mode){ FFI::Libevent::LOCKTYPE_RECURSIVE }
      include_examples :serialises
      include_examples :returns

      it "can lock many times over in single thread" do
        id = subject.lock_alloc(mode)
        ptr = FFI::Pointer.new(id)
        4.times do
          expect(subject.lock(0, ptr)).to eq 0
        end
        4.times do
          expect(subject.unlock(0, ptr)).to eq 0
        end

        # Expect this one to fail
        expect(subject.unlock(0, ptr)).not_to eq 0
      end
    end
  end

  pending "#cond_alloc" do
    
  end
end
