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
# but WITHOUT ANY WARRANTY; without even the implied warranty of # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the # GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Distributed Monitoring System.  If not, see <http://www.gnu.org/licenses/>.

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe DataProcessorBuilder do
	subject do
		Logging.logger.root.level = :fatal

		eval File.read(File.expand_path(File.dirname(__FILE__) + '/data_processor_builder_test1.rb'))
	end

	it 'should have name and data type' do
		subject.name.should == 'system CPU usage'
		subject.data_type_name.should == 'CPU usage'
	end

	it 'should provide data processors when raw data under new keys become available' do
		data_processors = subject.data_processors(RawDataKey['nina', 'system/CPU usage/CPU/0', 'user'])
		data_processors.should have(1).data_processors
		data_processors.shift.should be_a DataProcessor

		data_processors = subject.data_processors(RawDataKey['magi', 'system/CPU usage/CPU/1', 'system'])
		data_processors.should have(1).data_processors
		data_processors.shift.should be_a DataProcessor

		data_processors = subject.data_processors(RawDataKey['magi', 'system/CPU usage/CPU/1', 'user'])
		data_processors.should have(1).data_processors
		data_processors.shift.should be_a DataProcessor

		data_processors = subject.data_processors(RawDataKey['nina', 'system/CPU usage/CPU/0', 'system'])
		data_processors.should have(1).data_processors
		data_processors.shift.should be_a DataProcessor

		data_processors = subject.data_processors(RawDataKey['nina', 'system/CPU usage/CPU/0', 'stolen'])
		data_processors.should have(1).data_processors
		data_processors.shift.should be_a DataProcessor

		data_processors = subject.data_processors(RawDataKey['magi', 'system/CPU usage/total', 'user'])
		data_processors.should be_empty

		data_processors = subject.data_processors(RawDataKey['magi', 'system/CPU usage/total', 'system'])
		data_processors.should have(1).data_processors
		data_processors.shift.should be_a DataProcessor
	end

	describe DataProcessor do
		let(:data_processor) do
			subject.data_processors(RawDataKey['nina', 'system/CPU usage/CPU/0', 'user']).shift
		end

		it 'should have data type name' do
			data_processor.data_type_name.should == 'CPU usage'
		end

		it 'should have ID based on source of it' do
			subject.data_processors(RawDataKey['nina', 'system/CPU usage/CPU/0', 'user']).first.id.should == 'system CPU usage:count:nina'
			subject.data_processors(RawDataKey['magi', 'system/CPU usage/CPU/1', 'system']).first.id.should == 'system CPU usage:count:magi'
			subject.data_processors(RawDataKey['magi', 'system/CPU usage/CPU/1', 'user']).first.id.should == 'system CPU usage:cpu:magi:1'
			subject.data_processors(RawDataKey['nina', 'system/CPU usage/CPU/0', 'system']).first.id.should == 'system CPU usage:cpu:nina:0'
			subject.data_processors(RawDataKey['nina', 'system/CPU usage/CPU/0', 'stolen']).first.id.should == 'system CPU usage:cpu:nina:0'
			subject.data_processors(RawDataKey['magi', 'system/CPU usage/total', 'user']).should be_empty
			subject.data_processors(RawDataKey['magi', 'system/CPU usage/total', 'system']).first.id.should == 'system CPU usage:total:magi'
		end

		it 'should have a tag set based on available raw data' do
			subject.data_processors(RawDataKey['nina', 'system/CPU usage/CPU/0', 'user']).first.tag_set.should == TagSet[
				Tag.new('hello'), 
				Tag.new('world'), 
				Tag.new('location:nina'), 
				Tag.new('system:CPU count')
			]

			subject.data_processors(RawDataKey['magi', 'system/CPU usage/CPU/1', 'system']).first.tag_set.should == TagSet[
				Tag.new('hello'), 
				Tag.new('world'), 
				Tag.new('location:magi'), 
				Tag.new('system:CPU count')
			]

			subject.data_processors(RawDataKey['magi', 'system/CPU usage/CPU/1', 'user']).first.tag_set.should == TagSet[
				Tag.new('hello'), 
				Tag.new('world'), 
				Tag.new('location:magi'), 
				Tag.new('system:CPU usage:CPU:1')
			]

			subject.data_processors(RawDataKey['nina', 'system/CPU usage/CPU/0', 'system']).first.tag_set.should == TagSet[
				Tag.new('hello'), 
				Tag.new('world'), 
				Tag.new('location:nina'), 
				Tag.new('system:CPU usage:CPU:0')
			]

			subject.data_processors(RawDataKey['nina', 'system/CPU usage/CPU/0', 'stolen']).first.tag_set.should == TagSet[
				Tag.new('hello'), 
				Tag.new('world'), 
				Tag.new('location:nina'), 
				Tag.new('system:CPU usage:CPU:0'), 
				Tag.new('virtual')
			]

			subject.data_processors(RawDataKey['magi', 'system/CPU usage/total', 'user']).should be_empty

			subject.data_processors(RawDataKey['magi', 'system/CPU usage/total', 'system']).first.tag_set.should == TagSet[
				Tag.new('hello'), 
				Tag.new('world'), 
				Tag.new('location:magi'), 
				Tag.new('system:CPU usage:total')
			]
		end

		it 'should have a proper key set' do
			subject.data_processors(RawDataKey['nina', 'system/CPU usage/CPU/0', 'user']).first.raw_data_key_set.should == RawDataKeySet[
				RawDataKey['nina', 'system/CPU usage/CPU/0', 'user']
			]

			subject.data_processors(RawDataKey['magi', 'system/CPU usage/CPU/1', 'system']).first.raw_data_key_set.should == RawDataKeySet[
				RawDataKey['magi', 'system/CPU usage/CPU/1', 'system']
			]

			subject.data_processors(RawDataKey['magi', 'system/CPU usage/CPU/1', 'user']).first.raw_data_key_set.should == RawDataKeySet[
				RawDataKey['magi', 'system/CPU usage/CPU/1', 'user'],
				RawDataKey['magi', 'system/CPU usage/CPU/1', 'system']
			]

			subject.data_processors(RawDataKey['nina', 'system/CPU usage/CPU/0', 'system']).first.raw_data_key_set.should == RawDataKeySet[
				RawDataKey['nina', 'system/CPU usage/CPU/0', 'user'],
				RawDataKey['nina', 'system/CPU usage/CPU/0', 'system']
			]

			subject.data_processors(RawDataKey['nina', 'system/CPU usage/CPU/0', 'stolen']).first.raw_data_key_set.should == RawDataKeySet[
				RawDataKey['nina', 'system/CPU usage/CPU/0', 'user'],
				RawDataKey['nina', 'system/CPU usage/CPU/0', 'system'],
				RawDataKey['nina', 'system/CPU usage/CPU/0', 'stolen'],
			]

			subject.data_processors(RawDataKey['magi', 'system/CPU usage/total', 'user']).should be_empty
			subject.data_processors(RawDataKey['magi', 'system/CPU usage/total', 'system']).first.raw_data_key_set.should == RawDataKeySet[
				RawDataKey['magi', 'system/CPU usage/total', 'user'],
				RawDataKey['magi', 'system/CPU usage/total', 'system']
			]
		end
	end
end

