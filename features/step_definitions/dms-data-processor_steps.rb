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

Given /use linger time of (.+)/ do |linger_time|
	@program_args << ['--linger-time', linger_time.to_i]
end

Given /data bind address is (.*)/ do |address|
	@program_args << ['--data-bind-address', address]
end

Given /query bind address is (.*)/ do |address|
	@program_args << ['--query-bind-address', address]
end

Given /console connector subscribe address is (.*)/ do |address|
	@program_args << ['--console-subscriber', address]
	@console_connector_sub_address = address
end

Given /console connector publish address is (.*)/ do |address|
	@program_args << ['--console-publisher', address]
	@console_connector_pub_address = address
end

When /it is started$/ do
	@program_args = @program_args.join(' ')

	puts "#{@program} #{@program_args}"
	@program_process = RunProgram.new(@program, @program_args){|line| puts line}
end

When /I sent following RawDataPoints to (.*):/ do |address, raw_data_points|
	Timeout.timeout(4) do
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
					req.send DataSetQuery.new(h[:tag_expression], h[:time_from].to_i, h[:time_span].to_f, h[:granularity]) do |response|
						@query_resoults << response
					end.receive!
				end
			end
		end
	end
end

When /I publish following DataSetQueries on (.*) topic waiting for (.*) data sets/ do |topic, data_set_count, data_set_queries|
	@query_resoults = []

	Timeout.timeout 4 do
		ZeroMQ.new do |zmq|
			zmq.pub_bind(@console_connector_pub_address) do |pub|
				zmq.sub_bind(@console_connector_sub_address) do |sub|
					poller = ZeroMQ::Poller.new
					got_hello = nil

					sub.on Hello, topic do |msg|
						got_hello = true
					end

					poller << sub
					begin 
						pub.send Discover.new, topic: topic
						poller.poll(0.2)
					end until got_hello 

					sub.on DataSet, topic do |msg|
						@query_resoults << msg
					end

					data_set_queries.hashes.each do |h|
						pub.send DataSetQuery.new(h[:tag_expression], h[:time_from].to_i, h[:time_span].to_f, h[:granularity]), topic: topic
					end

					loop do
						sub.receive!
						break if @query_resoults.length == data_set_count.to_i
					end
				end
			end
		end
	end
end

When /I keep publishing Discover messages on (.*) topic/ do |topic|
	@publisher_thread = Thread.new do
		ZeroMQ.new do |zmq|
			zmq.pub_bind(@console_connector_pub_address, linger: 0) do |pub|
				loop do
					pub.send Discover.new, topic: topic
					sleep 0.2
				end
			end
		end
	end
end

When /I should eventually get Hello response on (.*) topic/ do |topic|
	message = nil
	Timeout.timeout 4 do
		ZeroMQ.new do |zmq|
			zmq.sub_bind(@console_connector_sub_address) do |sub|
				sub.on Hello, topic do |msg|
					message = msg
				end.receive!
			end
		end
	end

	@publisher_thread.kill
	@publisher_thread.join

	message.should be_a Hello
	message.host_name.should == Facter.fqdn
	message.program.should == 'dms-data-processor'
	message.pid.should > 0
end

When /I publish Discover messages as follows:/ do |discovers|
	Timeout.timeout 4 do
		ZeroMQ.new do |zmq|
			zmq.pub_bind(@console_connector_pub_address) do |pub|
				zmq.sub_bind(@console_connector_sub_address) do |sub|
					got_init = nil
					sub.on Hello, 'init' do |msg|
						got_init = true
					end

					poller = ZeroMQ::Poller.new
					poller << sub
					begin 
						pub.send Discover.new, topic: 'init'
						poller.poll(0.2)
					end until got_init 

					@hello_topics = {}
					discovers.hashes.each do |d|
						unless @hello_topics.has_key? d[:topic] 
							@hello_topics[d[:topic]] = []
							sub.on Hello, d[:topic] do |msg, topic|
								@hello_topics[d[:topic]] << msg
							end
						end

						pub.send Discover.new(d[:host_name], d[:program]), topic: d[:topic]
					end

					got_end = nil
					sub.on Hello, 'end' do |msg, topic|
						got_end = true
					end

					pub.send Discover.new, topic: 'end'

					until got_end
						sub.receive!
					end
				end
			end
		end
	end
end

Then /I should get (.*) Hello messages on (.*) topic/ do |count, topic|
	@hello_topics[topic].should have(count.to_i).messages
	@hello_topics[topic].each{|message| message.should be_a Hello}
end

Then /terminate the process/ do
	@program_process.terminate
end

Then /I should get following DataSets:/ do |data_sets|
	@query_resoults.should have(data_sets.hashes.length).data_sets

	data_sets.hashes.zip(@query_resoults).each do |h, result|
		result.type_name.should == h[:type_name]
		result.tag_set.to_s.should == h[:tag_set]
		result.time_from.to_i.should == h[:time_from].to_i
		result.time_span.to_f.should == h[:time_span].to_f
		h[:components].split(/, */).zip(h[:datum_count].split(/, */)).each do |component, count|
			result.component_data[component].length.should == count.to_i
		end
	end
end

Then /I should get NoResults response/ do
	@query_resoults.should have(1).response
	@query_resoults.first.should be_a NoResults
end

Then /log output should include following entries:/ do |log_entries|
	@program_log = @program_process.output
	log_entries.raw.flatten.each do |entry|
		@program_log.should include(entry)
	end
end

