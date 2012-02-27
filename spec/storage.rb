# Copyright (c) 2012 Jakub Pastuszek
#
# This file is part of Distributed Monitoring System.
#
# Distributed Monitoring System is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Distributed Monitoring System is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Distributed Monitoring System.  If not, see <http://www.gnu.org/licenses/>.

shared_examples_for 'storage' do
	it '#store should return true if this is first time raw datum was stored under given raw data key' do
		subject.store(RawDataKey['magi', 'CPU usage/CPU/1', 'usage'], RawDatum.new(Time.at(0), 123)).should == true
		subject.store(RawDataKey['magi', 'CPU usage/CPU/1', 'usage'], RawDatum.new(Time.at(1), 124)).should == false
		subject.store(RawDataKey['magi', 'CPU usage/CPU/1', 'usage'], RawDatum.new(Time.at(2), 125)).should == false
	end

	describe '#fetch' do
		it 'should return data for given key' do
			3.times do |sample|
				subject.store(RawDataKey['magi', 'system/CPU usage/cpu/0', 'idle'], sample * 1)
				subject.store(RawDataKey['magi', 'system/CPU usage/cpu/0', 'usage'], sample * 2)
				subject.store(RawDataKey['nina', 'system/CPU usage/cpu/0', 'idle'], sample * 4)
				subject.store(RawDataKey['nina', 'system/CPU usage/cpu/1', 'usage'], sample * 8)
			end

			subject.fetch(RawDataKey['magi', 'system/CPU usage/cpu/0', 'idle']).to_a.should == [2, 1, 0]
			subject.fetch(RawDataKey['magi', 'system/CPU usage/cpu/0', 'usage']).to_a.should == [4, 2, 0]
			subject.fetch(RawDataKey['nina', 'system/CPU usage/cpu/0', 'idle']).to_a.should == [8, 4, 0]
			subject.fetch(RawDataKey['nina', 'system/CPU usage/cpu/1', 'usage']).to_a.should == [16, 8, 0]
		end
		
		it 'should behave like Hash#fetch' do
			subject.store(RawDataKey['magi', 'system/CPU usage/cpu/0', 'idle'], 1)
			expect {
				subject.fetch(RawDataKey['magi', 'system/CPU usage/cpu', 'idle']).should be_nil
			}.to raise_error(KeyError, 'key not found')
			subject.fetch(RawDataKey['magi', 'system/CPU usage/cpu', 'idle'], nil).should be_nil
			subject.fetch(RawDataKey['magi', 'system/CPU usage/cpu/0', 'idle'], nil).should_not be_nil
		end
	end
end

