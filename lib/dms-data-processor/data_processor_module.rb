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

class DataProcessorModule < ModuleBase
	def initialize(module_name, &block)
		@data_processor_builders = []
		dsl_method :data_processor do |data_type_name, &block|
			DataProcessorBuilder.new("#{module_name}/#{data_type_name}", data_type_name, &block).tap{|data_processor_builder| @data_processor_builders << data_processor_builder}
		end

		super

		if @data_processor_builders.empty?
			log.warn "module '#{module_name}' defines no data processors"
		else
			log.info { "loaded data processors for data types: #{@data_processor_builders.map{|dpb| "#{dpb.data_type_name}"}.sort.join(', ')}" }
		end
	end

	attr_reader :data_processor_builders
end

class DataProcessorModules < ModuleLoader
	def initialize
		super(DataProcessorModule)
	end
end

