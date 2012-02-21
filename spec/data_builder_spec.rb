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
			value_range 0...100
		end
	end

	subject do
		DataBuilder.new('CPU usage', tag_space, storage_controller) do
			component 'user'
			component 'system'

			# registered when all non-optional components for single matching prefix are available
			tag 'system:CPU usage'

			prefix '/system/CPU usage' do |location, path, components|
				tag "location:#{location}"
				tag "virtual" if components.has_key? 'stolen'
			end

			prefix '/system/CPU usage/cpu' do |location, path, components|
				tag "system:CPU usage:CPU:#{path.split('/').last}"
			end

			prefix '/system/CPU usage/total' do |location, path, components|
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
end

