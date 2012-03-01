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

Given /data processor module directory (.+) containing module (.+):/ do |module_dir, module_name, module_content|
	@module_dirs ||= {}
	module_name = module_name.to_sym

	module_dir = @module_dirs[module_dir] ||= temp_dir("data_processor_#{module_dir}")

	(module_dir + "#{module_name}.rb").open('w') do |f|
		f.write(module_content)
	end
end

Given /using data processor modules directory (.+)/ do |module_dir|
	raise "module dir #{module_dir} not defined!" unless @module_dirs.member? module_dir
	@program_args << ['--module-dir', @module_dirs[module_dir].to_s]
end

Given /(.+) program$/ do |program|
	@program = program
	@program_args = []
end

Given /debug enabled/ do
	@program_args << ['--debug']
end

Given /data bind address is (.*)/ do |address|
	@program_args << ['--data-bind-address', address]
end

Given /query bind address is (.*)/ do |address|
	@program_args << ['--query-bind-address', address]
end

When /it is started for (.*) quer/ do |query_count|
	@program_args << ['--query-count', query_count.to_i]
	@program_args = @program_args.join(' ')

	puts "#{@program} #{@program_args}"
	@program_pid, @program_thread, @program_out_queue = spawn(@program, @program_args)
end

When /I sent following RawDataPoints to (.*):/ do |address, raw_data_points|
	Timeout.timeout(2) do
		ZeroMQ.new do |zmq|
			zmq.push_connect(address) do |push|
				 raw_data_points.hashes.each do |h|
					push.send RawDataPoint.new(h[:location], h[:path], h[:component], h[:value].to_i, h[:timestamp].to_i)
				end
			end
		end
	end
end

When /I send following DataSetQueries to (.*):/ do |address, data_set_queries|
	@query_resoults = []
	Timeout.timeout(2) do
		ZeroMQ.new do |zmq|
			zmq.req_connect(address) do |req|
				 data_set_queries.hashes.each do |h|
					req.send DataSetQuery.new(h[:query_id], h[:tag_expression], h[:time_from].to_i, h[:time_to].to_i, h[:granularity])
					@query_resoults.concat req.recv_all
				end
			end
		end
	end
end

Then /I should get following DataSets:/ do |data_sets|
	@query_resoults.should have(data_sets.hashes.length).data_sets

	data_sets.hashes.zip(@query_resoults).each do |h, result|
		result.type_name.should == h[:type_name]
		result.tag_set.to_s.should == h[:tag_set]
		result.time_from.to_i.should == h[:time_from].to_i
		result.time_to.to_i.should == h[:time_to].to_i
		h[:components].split(/, */).zip(h[:datum_count].split(/, */)).each do |component, count|
			result.component_data[component].length.should == count.to_i
		end
	end
end

Then /I should get NoResults response/ do
	@query_resoults.should have(1).response
	@query_resoults.first.should be_a NoResults
end

And /it should exit with (.*)/ do |exitstatus|
	Timeout.timeout(2) do 
		Process.waitpid(@program_pid)
		@program_thread.join
	end

	$?.exitstatus.should == exitstatus.to_i
	
	@program_log = []
	until @program_out_queue.empty?
		l = @program_out_queue.pop
		@program_log << l
		puts l
	end
	@program_log = @program_log.join
end

Then /log output should include following entries:/ do |log_entries|
	log_entries.raw.flatten.each do |entry|
		@program_log.should include(entry)
	end
end

