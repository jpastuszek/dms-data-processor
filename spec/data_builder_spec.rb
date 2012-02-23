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

describe DataBuilder do
	let(:tag_space) do
		TagSpace.new
	end

	let(:storage_controller) do
		StorageController.new(MemoryStorage.new(10))
	end

	let(:data_type) do
		DataType.new('CPU usage') do
			unit '%'
			range 0...100
		end
	end

	subject do
		DataBuilder.new(data_type, tag_space, storage_controller) do
			tag 'hello'
			tag 'world'

			data_set(:cpu_time_delta) do
				needs ':system/CPU usage/CPU[user, system]'

				on do |location, path, components|
					tag "location:#{location}"
					tag "virtual" if components.include? 'stolen'
					tag "system:CPU usage:CPU:#{path.split('/').last}"
				end
			end

			data_set(:cpu_time_delta) do
				needs 'system/CPU usage/total', 'user', 'system'

				on do |location, path, components|
					tag "location:#{location}"
					tag "system:CPU usage:total"
				end
			end

			data_sets(:cpu_spread) do
				select do |location, path, components|
					path.match('system/CPU usage/CPU/*') and components.superset?('usage', 'system')
				end.group_by do |location, path, components|
					group path.split('/').last
					group location
				end.tag do |group|
					tag "location:#{location}"
					tag "system:CPU usage:CPU:#{group}"
				end

				map
				
				map ':system/CPU usage/total[user, system, stolen]'

				on do |keys|
					keys.each do |key|
						tag "location:#{key.location}"
					end
					tag "system:virtualization:CPU cost"
				end
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

			processor(:cpu_spread) do |time_from, time_to, data_sources|
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
		subject # initialize subject

		storage_controller.store('nina', 'system/CPU usage/CPU/0', 'user', 1)
		storage_controller.store('magi', 'system/CPU usage/CPU/1', 'system', 2)

		tag_space['CPU usage'].should be_empty
		tag_space['location:magi'].should be_empty
		tag_space['system:CPU usage:CPU:1'].should be_empty
		tag_space['system:CPU usage:CPU:0'].should be_empty

		storage_controller.store('magi', 'system/CPU usage/CPU/1', 'user', 2)

		tag_space['system:CPU usage'].should have(1).data_builder
		tag_space['location:magi'].should have(1).data_builder
		tag_space['system:CPU usage:CPU:1'].should have(1).data_builder

		tag_space['location:nina'].should be_empty
		tag_space['system:CPU usage:CPU:0'].should be_empty
		tag_space['system:CPU usage:total'].should be_empty

		storage_controller.store('nina', 'system/CPU usage/CPU/0', 'system', 4)

		tag_space['location:nina'].should have(1).data_builder
		tag_space['virtual'].should be_empty
		tag_space['system:CPU usage:CPU:0'].should have(1).data_builder

		tag_space['system:CPU usage:total'].should be_empty

		storage_controller.store('nina', 'system/CPU usage/CPU/0', 'stolen', 3)
		tag_space['virtual'].should have(1).data_builder

		storage_controller.store('magi', 'system/CPU usage/total', 'user', 6)
		storage_controller.store('magi', 'system/CPU usage/total', 'system', 7)

		tag_space['system:CPU usage:total'].should have(1).data_builder
		tag_space['CPU usage'].should have(1).data_builder
	end

	it 'should provide list of supported tags' do
		pending "need new concept"
		subject # initialize subject
		subject.tags.should be_empty

		storage_controller.store('nina', 'system/CPU usage/CPU/0', 'user', 1)
		storage_controller.store('nina', 'system/CPU usage/CPU/0', 'system', 1)

		subject.tags.should == Set['location:nina', 'system:CPU usage:CPU:0', 'hello', 'world']

		storage_controller.store('nina', 'system/CPU usage/CPU/0', 'stolen', 1)
		subject.tags.should == Set['location:nina', 'system:CPU usage:CPU:0', 'hello', 'world', 'virtual']
	end

	it 'should provide data sets' do
		pending "need more tag stuf"
		subject # initialize subject

		20.time do |time|
			datum = [Time.at(time), time * 10]
			storage_controller.store('magi', 'system/CPU usage/CPU/0', 'user', dataum)
			storage_controller.store('magi', 'system/CPU usage/CPU/0', 'system', datum)

			storage_controller.store('nina', 'system/CPU usage/CPU/0', 'user', dataum)
			storage_controller.store('nina', 'system/CPU usage/CPU/0', 'system', datum)
			storage_controller.store('nina', 'system/CPU usage/CPU/0', 'stolen', datum)
		end

		data_builders = tag_space['hello']
		data_builders.should have(1).data_builder

		data_builder = data_builders.shift
		data_sets = data_builder.data_sets('hello', Time.at(10)...Time.at(4))

		data_sets = data_builder.data_sets('system:CPU usage:total', Time.at(10)...Time.at(4))

		data_sets = data_builder.data_sets('system:CPU usage:CPU:1', Time.at(10)...Time.at(4))
	end
end

