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

		DataProcessorBuilder.new(:system_cpu_usage, 'CPU usage') do
			tag 'hello'
			tag 'world'

			data_processor(:cpu).select do
				key 'system/CPU usage/CPU[user, system, stolen]'
			end.group do |raw_data_key|
				by raw_data_key.location
				by raw_data_key.path.last
			end.need do
				key 'system/CPU usage/CPU[user]'
				key 'system/CPU usage/CPU[system]'
			end.each_group do |group, raw_data_keys|
				tag "location:#{group.first}"
				tag "system:CPU usage:CPU:#{group.last}"

				tag "virtual" if raw_data_keys.any? do |raw_data_key|
					raw_data_key.component == 'stolen'
				end
			end.process_with(:cpu_time_delta)

			data_processor(:total).select do
				key 'system/CPU usage/total[user, system, stolen]'
			end.group do |raw_data_key|
				by raw_data_key.location
			end.need do
				key 'system/CPU usage/total[user]'
				key 'system/CPU usage/total[system]'
			end.each_group do |group, raw_data_keys|
				tag "location:#{group.first}"
				tag "system:CPU usage:total"

				tag "virtual" if raw_data_keys.any? do |raw_data_key|
					raw_data_key.component == 'stolen'
				end
			end.process_with :cpu_time_delta

			data_processor(:count).select do
				key 'system/CPU usage/CPU'
			end.group do |raw_data_key|
				by raw_data_key.location
			end.need do
				key 'system/CPU usage/CPU'
			end.each_group do |group, raw_data_keys|
				tag "location:#{group.first}"
				tag "system:CPU count"
			end.process_with do |time_from, time_to, data_sources|
				collect data_sources.keys.length
			end

			processor(:cpu_time_delta) do |time_from, time_to, data_sources|
				data_sources.each_pair do |path, location_node|
					location_node.each_pair do |location, component_node|
						component_node do |component, raw_data|
							rd = raw_data.range(time_from, time_to)

							old = nil
							rd.each do |new|
								if old
									time_delta = (new.time - old.time).to_f
									value_delta = (new.value - old.value).to_f / 1000

									collect name, new.time - (time_delta / 2),  value_delta / time_delta
								end
								old = new
							end
						end
					end
				end
			end
		end
	end

	it 'should have name and data type' do
		subject.name.should == :system_cpu_usage
		subject.data_type.should == 'CPU usage'
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

		it 'should have data type' do
			data_processor.data_type.should == 'CPU usage'
		end

		it 'should have ID based on source of it' do
			subject.data_processors(RawDataKey['nina', 'system/CPU usage/CPU/0', 'user']).first.id.should == 'system_cpu_usage:count:nina'
			subject.data_processors(RawDataKey['magi', 'system/CPU usage/CPU/1', 'system']).first.id.should == 'system_cpu_usage:count:magi'
			subject.data_processors(RawDataKey['magi', 'system/CPU usage/CPU/1', 'user']).first.id.should == 'system_cpu_usage:cpu:magi:1'
			subject.data_processors(RawDataKey['nina', 'system/CPU usage/CPU/0', 'system']).first.id.should == 'system_cpu_usage:cpu:nina:0'
			subject.data_processors(RawDataKey['nina', 'system/CPU usage/CPU/0', 'stolen']).first.id.should == 'system_cpu_usage:cpu:nina:0'
			subject.data_processors(RawDataKey['magi', 'system/CPU usage/total', 'user']).should be_empty
			subject.data_processors(RawDataKey['magi', 'system/CPU usage/total', 'system']).first.id.should == 'system_cpu_usage:total:magi'
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

