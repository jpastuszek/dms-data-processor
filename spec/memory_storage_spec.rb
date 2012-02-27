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

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'storage'

describe MemoryStorage do
	subject do
		MemoryStorage.new(3)
	end

	it_behaves_like 'storage'

	it 'should not store more than specified number of objects under same key but keep the most recen objects' do
		subject.store(RawDataKey['magi', 'system/CPU usage/cpu/0', 'idle'], 1)
		subject.store(RawDataKey['magi', 'system/CPU usage/cpu/0', 'idle'], 2)
		subject.store(RawDataKey['magi', 'system/CPU usage/cpu/0', 'idle'], 3)
		subject.store(RawDataKey['magi', 'system/CPU usage/cpu/0', 'idle'], 4)

		subject.fetch(RawDataKey['magi', 'system/CPU usage/cpu/0', 'idle']).to_a.should == [4, 3, 2]
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

