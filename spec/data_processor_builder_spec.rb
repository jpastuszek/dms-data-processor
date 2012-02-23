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
	let(:data_type) do
		DataType.new('CPU usage') do
			unit '%'
			range 0...100
		end
	end

	subject do
		DataProcessorBuilder.new(:system_cpu_usage, data_type) do
			tag 'hello'
			tag 'world'

			data_processor(:cpu).select do
				key 'system/CPU usage/CPU[user, system, stolen]'
			end.group do |raw_data_key|
				by raw_data_key.location
				by raw_data_key.path.last
			end.need do
				key 'system/CPU usage/CPU[user, system]'
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
				key 'system/CPU usage/CPU[user, system]'
			end.each_group do |group, raw_data_keys|
				tag "location:#{group.first}"
				tag "system:CPU usage:CPU:total"

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
				tag "system:CPU usage:CPU:total"

				tag "virtual" if raw_data_keys.any? do |raw_data_key|
					raw_data_key.component == 'stolen'
				end
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

	it 'should have data type' do
		pending "need new concept"
		subject.data_type.name.should == 'CPU usage'
	end

	it 'should not cause tags to be defined untill all required components of given path are stored' do
		pending "need new concept"
		Logging.logger.root.level = :debug

		data_processors = []
		subject.each do |data_processor|
			data_processor << data_processor
		end

		subject.key RawDataKey['nina', 'system/CPU usage/CPU/0', 'user']
		subject.key RawDataKey['magi', 'system/CPU usage/CPU/1', 'system']
		data_processors.should have(0).data_processors

		subject.key RawDataKey['magi', 'system/CPU usage/CPU/1', 'user']
		data_processors.should have(1).data_processors
		data_processors.first.should be_a(DataProcessor)
		data_processors.shift.tags.should == TagSet['system:CPU usage, location:magi, system:CPU usage:CPU:1']

		subject.key RawDataKey['nina', 'system/CPU usage/CPU/0', 'system']
		data_processors.shift.tags.should == TagSet['system:CPU usage, location:nina, system:CPU usage:CPU:0']

		subject.key RawDataKey['nina', 'system/CPU usage/CPU/0', 'stolen']
		data_processors.shift.tags.should == TagSet['system:CPU usage, location:nina, system:CPU usage:CPU:0, virtual']

		subject.key RawDataKey['magi', 'system/CPU usage/total', 'user']
		subject.key RawDataKey['magi', 'system/CPU usage/total', 'system']
		data_processors.shift.tags.should == TagSet['system:CPU usage, location:magi, system:CPU usage:total']
	end
end
