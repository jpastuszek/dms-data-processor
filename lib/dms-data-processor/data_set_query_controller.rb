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

class DataSetQueryController
	def initialize(storage_controller)
		@storage_controller = storage_controller
	end

	def query(data_set_query)
		data_sets = []
		@storage_controller[data_set_query.tag_expression].each do |data_source|
			have_data = false
			data_set = DataSet.new(data_source.data_type_name, data_source.tag_set, data_set_query.time_from, data_set_query.time_to) do
				data_source.data_set(data_set_query.time_from, data_set_query.time_to).each_pair do |component, data|
					data.each do |time, value|
						component_data component, time, value
						have_data = true
					end
				end
			end
			data_sets << data_set if have_data
		end
		data_sets
	end
end

