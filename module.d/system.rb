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

data_processor('CPU usage') do
	classifier('cpu').select do
		key 'system/CPU usage/CPU'
	end.group do |raw_data_key|
		by raw_data_key.location
		by raw_data_key.path.last
	end.need do
		key 'system/CPU usage/CPU[user]'
		key 'system/CPU usage/CPU[nice]'
		key 'system/CPU usage/CPU[system]'
		key 'system/CPU usage/CPU[idle]'
		key 'system/CPU usage/CPU[iowait]'
	end.each_group do |group, raw_data_keys|
		tag "location:#{group.first}"
		tag "system:CPU usage:CPU:#{group.last}"

		tag "virtual" if raw_data_keys.any? do |raw_data_key|
			raw_data_key.component == 'steal' or raw_data_key.component == 'virtual'
		end
	end.process_with(:cpu_time_delta)

	classifier('total').select do
		key 'system/CPU usage/total'
	end.group do |raw_data_key|
		by raw_data_key.location
	end.need do
		key 'system/CPU usage/total[user]'
		key 'system/CPU usage/total[nice]'
		key 'system/CPU usage/total[system]'
		key 'system/CPU usage/total[idle]'
		key 'system/CPU usage/total[iowait]'
	end.each_group do |group, raw_data_keys|
		tag "location:#{group.first}"
		tag "system:CPU usage:total"

		tag "virtual" if raw_data_keys.any? do |raw_data_key|
			raw_data_key.component == 'steal' or raw_data_key.component == 'virtual'
		end
	end.process_with :cpu_time_delta

	processor(:cpu_time_delta) do |time_from, time_span, data_sources|
		data_sources.each do |raw_data_key, raw_data|
			rd = raw_data.range(time_from, time_span)

			old = nil
			rd.each do |new|
				if old
					time_delta = (new.time_stamp - old.time_stamp).to_f
					value_delta = (new.value - old.value).to_f / 100

					collect raw_data_key.component, new.time_stamp - (time_delta / 2),  value_delta / time_delta
				end
				old = new
			end
		end
	end
end

