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

	it 'should return data enumerable in revers time stamp order but no more than storage size (3)' do
		subject.store(RawDataKey['magi', 'system/CPU usage/cpu/0', 'idle'], RawDatum[Time.at(3), 3])
		subject.store(RawDataKey['magi', 'system/CPU usage/cpu/0', 'idle'], RawDatum[Time.at(1), 1])
		subject.store(RawDataKey['magi', 'system/CPU usage/cpu/0', 'idle'], RawDatum[Time.at(4), 4])
		subject.store(RawDataKey['magi', 'system/CPU usage/cpu/0', 'idle'], RawDatum[Time.at(2), 2])

		d = subject.fetch(RawDataKey['magi', 'system/CPU usage/cpu/0', 'idle'])

		d.should respond_to :each
		d.to_a.should == [
			RawDatum[Time.at(4), 4],
			RawDatum[Time.at(3), 3],
			RawDatum[Time.at(2), 2],
		]
	end
end

