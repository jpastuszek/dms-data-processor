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

describe RawDataKey do
	it 'consists of location, path and component' do
		rdk = RawDataKey.new('magi', 'hello/world', 'usage')
		rdk.location.should == 'magi'
		rdk.path.should == 'hello/world'
		rdk.component.should == 'usage'
	end

	it 'has short hand constructor' do
		rdk = RawDataKey['magi', 'hello/world', 'usage']
		rdk.location.should == 'magi'
		rdk.path.should == 'hello/world'
		rdk.component.should == 'usage'
	end

	describe 'path' do
		it 'allows access to its components like array' do
			rdk = RawDataKey['magi', 'hello/world', 'usage']
			rdk.path.first.should == 'hello'
			rdk.path.last.should == 'world'

			rdk.path.to_a.should == ['hello', 'world']
		end
	end

	describe 'match RawDataKeyPattern' do
		subject do
			RawDataKey['magi', 'system/CPU usage/total', 'user']
		end

		it 'matchs by prefix' do
			subject.should be_match RawDataKeyPattern.new('system/CPU usage[user]')
			subject.should be_match RawDataKeyPattern.new('system/CPU usage[user, system, stolen]')
			subject.should be_match RawDataKeyPattern.new('system/CPU usage')
			subject.should be_match RawDataKeyPattern.new('magi:system/CPU usage/total')
			subject.should be_match RawDataKeyPattern.new('/magi/:system/CPU usage/total')
			subject.should be_match RawDataKeyPattern.new(':system/CPU usage/total[]')
			subject.should be_match RawDataKeyPattern.new('')

			subject.should_not be_match RawDataKeyPattern.new('system/CPU usage/cpu/1')
			subject.should_not be_match RawDataKeyPattern.new('nina:system/CPU usage/total')
			subject.should_not be_match RawDataKeyPattern.new('system/CPU usage/total[stolen]')
			subject.should_not be_match RawDataKeyPattern.new('/magi1/:system/CPU usage/total')
		end
	end
end

describe RawDataKeyPattern do
	subject do
		[
			RawDataKeyPattern.new('system/CPU usage/total[user]'),
			RawDataKeyPattern.new('system/CPU usage/total[user, system, stolen]'),
			RawDataKeyPattern.new('system/CPU usage/total[user, system, system]'),
			RawDataKeyPattern.new('system/CPU usage/total'),
			RawDataKeyPattern.new(''),
			RawDataKeyPattern.new('magi:system/CPU usage/total'),
			RawDataKeyPattern.new('/magi/:system/CPU usage/total'),
			RawDataKeyPattern.new('magi:system/CPU usage/total[user, system, stolen]'),
			RawDataKeyPattern.new('magi:[user, system, stolen]'),
			RawDataKeyPattern.new(':system/CPU usage/total[]'),
		]
	end

	it 'should pares out location, prefix and component list from string' do
		rdkp = subject.shift
		rdkp.location.should be_nil
		rdkp.prefix.should == 'system/CPU usage/total'
		rdkp.components.should == Set['user']

		rdkp = subject.shift
		rdkp.location.should be_nil
		rdkp.prefix.should == 'system/CPU usage/total'
		rdkp.components.should == Set['user', 'system', 'stolen']

		rdkp = subject.shift
		rdkp.location.should be_nil
		rdkp.prefix.should == 'system/CPU usage/total'
		rdkp.components.should == Set['user', 'system']

		rdkp = subject.shift
		rdkp.location.should be_nil
		rdkp.prefix.should == 'system/CPU usage/total'
		rdkp.components.should be_empty

		rdkp = subject.shift
		rdkp.location.should be_nil
		rdkp.prefix.should be_nil
		rdkp.components.should be_empty

		rdkp = subject.shift
		rdkp.location.should == 'magi'
		rdkp.prefix.should == 'system/CPU usage/total'
		rdkp.components.should be_empty

		rdkp = subject.shift
		rdkp.location.should == /magi/ix
		rdkp.prefix.should == 'system/CPU usage/total'
		rdkp.components.should be_empty

		rdkp = subject.shift
		rdkp.location.should == 'magi'
		rdkp.prefix.should == 'system/CPU usage/total'
		rdkp.components.should == Set['user', 'system', 'stolen']

		rdkp = subject.shift
		rdkp.location.should == 'magi'
		rdkp.prefix.should be_nil
		rdkp.components.should == Set['user', 'system', 'stolen']

		rdkp = subject.shift
		rdkp.location.should be_nil
		rdkp.prefix.should == 'system/CPU usage/total'
		rdkp.components.should be_empty
	end

	it 'should parse from string and render back to string' do
		subject.shift.to_s.should == 'system/CPU usage/total[user]'
		subject.shift.to_s.should == 'system/CPU usage/total[user, system, stolen]'
		subject.shift.to_s.should == 'system/CPU usage/total[user, system]'
		subject.shift.to_s.should == 'system/CPU usage/total'
		subject.shift.to_s.should == ''
		subject.shift.to_s.should == 'magi:system/CPU usage/total'
		subject.shift.to_s.should == '/magi/:system/CPU usage/total'
		subject.shift.to_s.should == 'magi:system/CPU usage/total[user, system, stolen]'
		subject.shift.to_s.should == 'magi:[user, system, stolen]'
		subject.shift.to_s.should == 'system/CPU usage/total'
	end
end

describe RawDatum do
	it 'cosists of UTC time stamp and value' do
		rd = RawDatum.new(123, 42)
		rd.time_stamp.should == Time.at(123).utc
		rd.value.should == 42
	end

	it 'has short hand constructor' do
		rd = RawDatum[Time.at(0), 9]
		rd.time_stamp.should == Time.at(0).utc
		rd.value.should == 9
	end
end


describe StorageController do
	subject do
		StorageController.new(MemoryStorage.new(100))
	end

	it_behaves_like 'storage'

	it 'should notify on stored value under given prefix' do
		notices = []
		subject.notify_value('system') do |raw_data_key, raw_datum|
			notices << [1, raw_data_key, raw_datum]
		end

		subject.notify_value('system/CPU usage/cpu/0') do |raw_data_key, raw_datum|
			notices << [2, raw_data_key, raw_datum]
		end

		subject.notify_value('system/bogous') do |raw_data_key, raw_datum|
			notices << [3, raw_data_key, raw_datum]
		end

		subject.notify_value('jmx/tomcat') do |raw_data_key, raw_datum|
			notices << [4, raw_data_key, raw_datum]
		end

		subject.store(RawDataKey['magi', 'system/CPU usage/cpu/0', 'usage'], 213)
		notices.should have(2).notices
		notices.shift.should == [1, RawDataKey['magi', 'system/CPU usage/cpu/0', 'usage'], 213]
		notices.shift.should == [2, RawDataKey['magi', 'system/CPU usage/cpu/0', 'usage'], 213]

		subject.store(RawDataKey['nina', 'system/CPU usage/cpu/1', 'idle'], 123)
		notices.should have(1).notices
		notices.shift.should == [1, RawDataKey['nina', 'system/CPU usage/cpu/1', 'idle'], 123]

		subject.store(RawDataKey['nina', 'jmx/tomcat/test', 'idle'], 123)
		notices.should have(1).notices
		notices.shift.should == [4, RawDataKey['nina', 'jmx/tomcat/test', 'idle'], 123]

		subject.store(RawDataKey['nina', 'jmx/tomc', 'idle'], 123)
		notices.should have(0).notices

		subject.store(RawDataKey['nina', 'tomcat', 'idle'], 123)
		notices.should have(0).notices

		subject.store(RawDataKey['nina', 'jmx', 'idle'], 123)
		notices.should have(0).notices
	end

	it 'should notify when new component is stored under given path prefix' do
		notices = []
		subject.notify_raw_data_key('system') do |raw_data_key|
			notices << [1, raw_data_key]
		end

		subject.notify_raw_data_key('system/CPU usage/cpu/0') do |raw_data_key|
			notices << [2, raw_data_key]
		end

		subject.notify_raw_data_key('system/bogous') do |raw_data_key|
			notices << [3, raw_data_key]
		end

		subject.notify_raw_data_key('jmx/tomcat') do |raw_data_key|
			notices << [4, raw_data_key]
		end

		subject.store(RawDataKey['magi', 'system/CPU usage/cpu/0', 'usage'], 213)
		notices.should have(2).notices
		notices.shift.should == [1, RawDataKey['magi', 'system/CPU usage/cpu/0', 'usage']]
		notices.shift.should == [2, RawDataKey['magi', 'system/CPU usage/cpu/0', 'usage']]

		subject.store(RawDataKey['magi', 'system/CPU usage/cpu/0', 'idle'], 213)
		notices.should have(2).notices
		notices.shift.should == [1, RawDataKey['magi', 'system/CPU usage/cpu/0', 'idle']]
		notices.shift.should == [2, RawDataKey['magi', 'system/CPU usage/cpu/0', 'idle']]

		subject.store(RawDataKey['magi', 'system/CPU usage/cpu/0', 'idle'], 213)
		notices.should have(0).notices

		subject.store(RawDataKey['nina', 'system/CPU usage/cpu/1', 'idle'], 123)
		notices.should have(1).notices
		notices.shift.should == [1, RawDataKey['nina', 'system/CPU usage/cpu/1', 'idle']]

		subject.store(RawDataKey['nina', 'system/CPU usage/cpu/1', 'usage'], 123)
		notices.should have(1).notices
		notices.shift.should == [1, RawDataKey['nina', 'system/CPU usage/cpu/1', 'usage']]

		subject.store(RawDataKey['nina', 'jmx/tomcat/test', 'idle'], 123)
		notices.should have(1).notices
		notices.shift.should == [4, RawDataKey['nina', 'jmx/tomcat/test', 'idle']]

		subject.store(RawDataKey['nina', 'jmx/tomc', 'idle'], 123)
		notices.should have(0).notices

		subject.store(RawDataKey['nina', 'tomcat', 'idle'], 123)
		notices.should have(0).notices

		subject.store(RawDataKey['nina', 'jmx', 'idle'], 123)
		notices.should have(0).notices
	end
end

