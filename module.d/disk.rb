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

data_processor('Disk usage') do
	classifier('usage').select do
		key 'disk/usage'
	end.group do |raw_data_key|
		by raw_data_key.location
		by raw_data_key.path.sub 'disk/usage/', ''
	end.need do
		key 'disk/usage[total]'
		key 'disk/usage[free]'
		key 'disk/usage[used]'
	end.each_group do |group, raw_data_keys|
		tag "location:#{group.first}"
		tag "disk:usage:#{group.last}"
	end.process_with do |time_from, time_span, data_sources|
		data_sources.each do |raw_data_key, raw_data|
			raw_data.range(time_from, time_span).each do |data|
				collect raw_data_key.component, data.time_stamp, data.value
			end
		end
	end
end

