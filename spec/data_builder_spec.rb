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
			component 'user'
			component 'system'

			# registered when all non-optional components for single matching prefix are available
			tag 'system:CPU usage'
			tag 'hello world'

			prefix 'system/CPU usage' do |location, path, components|
				tag "location:#{location}"
				tag "virtual" if components.include? 'stolen'
			end

			prefix 'system/CPU usage/cpu' do |location, path, components|
				tag "system:CPU usage:CPU:#{path.split('/').last}"
			end

			prefix 'system/CPU usage/total' do |location, path, components|
				tag "system:CPU usage:total"
			end
			
			data do |time_from, time_to, components|
				components.each_pair do |name, raw_data|
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

	it 'should have data type' do
		subject.data_type.name.should == 'CPU usage'
	end

	it 'should not cause tags to be defined untill all required components of given path are stored' do
		Logging.logger.root.level = :debug
		subject # initialize subject

		storage_controller.store('magi', 'system/CPU usage/cpu/0', 'user', 1)
		storage_controller.store('magi', 'system/CPU usage/cpu/1', 'system', 2)

		tag_space['CPU usage'].should be_empty
		tag_space['location:magi'].should be_empty
		tag_space['system:CPU usage:CPU:1'].should be_empty
		tag_space['system:CPU usage:CPU:0'].should be_empty

		storage_controller.store('magi', 'system/CPU usage/cpu/0', 'stolen', 3)
		storage_controller.store('magi', 'system/CPU usage/cpu/1', 'user', 2)

		tag_space['system:CPU usage'].should have(1).data_builder
		tag_space['location:magi'].should have(1).data_builder
		tag_space['system:CPU usage:CPU:1'].should have(1).data_builder

		tag_space['virtual'].should be_empty
		tag_space['system:CPU usage:CPU:0'].should be_empty
		tag_space['system:CPU usage:total'].should be_empty

		storage_controller.store('magi', 'system/CPU usage/cpu/0', 'system', 4)

		tag_space['system:CPU usage:CPU:0'].should have(1).data_builder
		tag_space['virtual'].should have(1).data_builder

		tag_space['system:CPU usage:total'].should be_empty

		storage_controller.store('magi', 'system/CPU usage/total', 'user', 6)
		storage_controller.store('magi', 'system/CPU usage/total', 'system', 7)

		tag_space['system:CPU usage:total'].should have(1).data_builder
		tag_space['CPU usage'].should have(1).data_builder
	end
end

