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
	let(:data_processor_builder) do
		Logging.logger.root.level = :fatal

		eval File.read(File.expand_path(File.dirname(__FILE__) + '/data_processor_builder_test1.rb'))
	end

	subject do
		st = StorageController.new(MemoryStorage.new(100))
		st << data_processor_builder
		10.times do |sample|
			st.store(RawDataKey['nina', 'system/CPU usage/CPU/0', 'user'], RawDatum.new(Time.at(sample), sample * 1))
			st.store(RawDataKey['nina', 'system/CPU usage/CPU/0', 'system'], RawDatum.new(Time.at(sample), sample * 2))

			st.store(RawDataKey['magi', 'system/CPU usage/CPU/1', 'user'], RawDatum.new(Time.at(sample), sample * 2))
			st.store(RawDataKey['magi', 'system/CPU usage/CPU/1', 'system'], RawDatum.new(Time.at(sample), sample * 4))

			st.store(RawDataKey['nina', 'system/CPU usage/total', 'user'], RawDatum.new(Time.at(sample), sample * 4))
			st.store(RawDataKey['nina', 'system/CPU usage/total', 'system'], RawDatum.new(Time.at(sample), sample * 8))
		end
		st
	end

	it 'should provide data sources by tag expression' do
		subject['bogous'].should be_empty

		subject['hello'].should have(5).data_sources
		subject['hello'].each{|data_source| data_source.should be_a DataSource}

		subject['world'].should have(5).data_sources
		subject['system'].should have(5).data_sources
		subject['location'].should have(5).data_sources

		subject['nina'].should have(3).data_sources
		subject['magi'].should have(2).data_sources

		subject['CPU count'].should have(2).data_sources
		subject['total'].should have(1).data_sources
		subject['cpu:1'].should have(1).data_sources

		subject['/mag/'].should have(2).data_sources

		subject['/mag/, CPU usage'].should have(1).data_sources
	end

	describe DataSource do
		it 'should provide data type name' do
			subject['total'].first.data_type_name.should == 'CPU usage'
		end

		it 'should provide tag set' do
			subject['total'].first.tag_set.should be_a TagSet
			subject['total'].first.tag_set.to_s.should == 'hello, location:nina, system:CPU usage:total, world'
		end

		it 'should provide data for each data set component from time range' do
			data = subject['total'].first.data_set(Time.at(5), Time.at(0))
			data.should include('user')
			data.should include('system')

			data['user'].shift.should == [Time.at(4.5), 0.004]
			data['user'].shift.should == [Time.at(3.5), 0.004]
			data['user'].shift.should == [Time.at(2.5), 0.004]
			data['user'].shift.should == [Time.at(1.5), 0.004]
			data['user'].shift.should == [Time.at(0.5), 0.004]

			data['system'].shift.should == [Time.at(4.5), 0.008]
			data['system'].shift.should == [Time.at(3.5), 0.008]
			data['system'].shift.should == [Time.at(2.5), 0.008]
			data['system'].shift.should == [Time.at(1.5), 0.008]
			data['system'].shift.should == [Time.at(0.5), 0.008]
		end
	end
end

