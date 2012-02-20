require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe MemoryStorage do
	subject do
		MemoryStorage.new(3)
	end

	it 'should store value under component path and location' do
		subject.store('magi', 'system/CPU usage/cpu/0', 'idle', 12345)

		subject['system/CPU usage/cpu/0']['system/CPU usage/cpu/0']['magi']['idle'].to_a.should == [12345]
	end

	it 'should return nodes by path prefix' do
		subject.store('magi', 'system/CPU usage/cpu/0', 'idle', 12345)
		subject.store('magi', 'system/CPU usage/cpu/0', 'usage', 213)
		subject.store('magi', 'system/CPU usage/cpu/1', 'usage', 12)
		subject.store('nina', 'system/CPU usage/cpu/1', 'usage', 89)
		subject.store('nina', 'system/CPU usage/total', 'usage', 42)

		cpu = subject['system/CPU usage/cpu']
		cpu['system/CPU usage/cpu/0']['magi']['idle'].to_a.should == [12345]
		cpu['system/CPU usage/cpu/0']['magi']['usage'].to_a.should == [213]
		cpu['system/CPU usage/cpu/1']['magi']['usage'].to_a.should == [12]
		cpu['system/CPU usage/cpu/1']['nina']['usage'].to_a.should == [89]

		system = subject['system']
		system['system/CPU usage/cpu/0']['magi']['idle'].to_a.should == [12345]
		system['system/CPU usage/cpu/0']['magi']['usage'].to_a.should == [213]
		system['system/CPU usage/cpu/1']['magi']['usage'].to_a.should == [12]
		system['system/CPU usage/cpu/1']['nina']['usage'].to_a.should == [89]
		system['system/CPU usage/total']['nina']['usage'].to_a.should == [42]
	end

	it 'should store elements in fifo order' do
		subject.store('magi', 'system/CPU usage/cpu/0', 'idle', 1)
		subject.store('magi', 'system/CPU usage/cpu/0', 'idle', 2)
		subject.store('magi', 'system/CPU usage/cpu/0', 'idle', 3)

		system = subject['system']
		system['system/CPU usage/cpu/0']['magi']['idle'].to_a.should == [3, 2, 1]
	end

	it 'should not store more than specified number of objects under same key but keep the most recen objects' do
		subject.store('magi', 'system/CPU usage/cpu/0', 'idle', 1)
		subject.store('magi', 'system/CPU usage/cpu/0', 'idle', 2)
		subject.store('magi', 'system/CPU usage/cpu/0', 'idle', 3)
		subject.store('magi', 'system/CPU usage/cpu/0', 'idle', 4)

		system = subject['system']
		system['system/CPU usage/cpu/0']['magi']['idle'].to_a.should == [4, 3, 2]
	end

	describe MemoryStorage::RingBuffer do
		subject do
			MemoryStorage::RingBuffer.new(10)
		end

		it 'should iterate stored elements in reverse insertion order' do
			3.times do |time|
				subject << time
			end

			subject.first.should == 2
			
			subject.reduce([]) do |arr, elem|
				arr << elem
			end.should == [2, 1, 0]
		end

		it 'should keep last size number of elements' do
			20.times do |time|
				subject << time
			end

			subject.first.should == 19
			
			arr = subject.reduce([]) do |arr, elem|
				arr << elem
			end

			arr.should have(10).numbers
			arr.should == [19, 18, 17, 16, 15, 14, 13, 12, 11, 10]
		end
	end
end

