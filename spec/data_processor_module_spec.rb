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

describe DataProcessorModule do
	subject do
		dpm = nil
		Capture.stderr do
			dpm = DataProcessorModule.new('system') do
				data_processor('memory usage') do
				end

				data_processor('CPU usage') do
					tag 'module:system'

					classifier('cpu').select do
						key 'system/CPU usage/CPU[user, system, stolen]'
					end.group do |raw_data_key|
						by raw_data_key.location
						by raw_data_key.path.last
					end.need do
						key 'system/CPU usage/CPU[user]'
						key 'system/CPU usage/CPU[system]'
					end.each_group do |group, raw_data_keys|
						tag "location:#{group.first}"
						tag "system:CPU usage:CPU:#{group.last}"

						tag "virtual" if raw_data_keys.any? do |raw_data_key|
							raw_data_key.component == 'stolen'
						end
					end.process_with do |time_from, time_span, data_sources|
						data_sources.each do |raw_data_key, raw_data|
							rd = raw_data.range(time_from, time_span)

							old = nil
							rd.each do |new|
								if old
									time_delta = (new.time_stamp - old.time_stamp).to_f
									value_delta = (new.value - old.value).to_f / 1000

									collect raw_data_key.component, new.time_stamp - (time_delta / 2),  value_delta / time_delta
								end
								old = new
							end
						end
					end
				end
			end
		end
		dpm
	end

	it 'has a name' do
		subject.name.should == 'system'
	end

	it 'provides access to data processor builders' do
		subject.data_processor_builders.should have(2).data_processor_builders
		subject.data_processor_builders.shift.should be_a DataProcessorBuilder
		subject.data_processor_builders.shift.should be_a DataProcessorBuilder
	end
end

describe DataProcessorModules do
	before :all do
		Logging.logger.root.level = :debug
		@modules_dir = Pathname.new(Dir.mktmpdir('poller_moduled.d'))

		(@modules_dir + 'system.rb').open('w') do |f|
			f.write <<'EOF'
data_processor('memory usage') do
end

data_processor('CPU usage') do
	tag 'module:system'

	classifier('cpu').select do
		key 'system/CPU usage/CPU[user, system, stolen]'
	end.group do |raw_data_key|
		by raw_data_key.location
		by raw_data_key.path.last
	end.need do
		key 'system/CPU usage/CPU[user]'
		key 'system/CPU usage/CPU[system]'
	end.each_group do |group, raw_data_keys|
		tag "location:#{group.first}"
		tag "system:CPU usage:CPU:#{group.last}"

		tag "virtual" if raw_data_keys.any? do |raw_data_key|
			raw_data_key.component == 'stolen'
		end
	end.process_with do |time_from, time_span, data_sources|
		data_sources.each do |raw_data_key, raw_data|
			rd = raw_data.range(time_from, time_span)

			old = nil
			rd.each do |new|
				if old
					time_delta = (new.time_stamp - old.time_stamp).to_f
					value_delta = (new.value - old.value).to_f / 1000

					collect raw_data_key.component, new.time_stamp - (time_delta / 2),  value_delta / time_delta
				end
				old = new
			end
		end
	end
end
EOF
		end

		(@modules_dir + 'empty.rb').open('w') do |f|
			f.write('')
		end

		(@modules_dir + 'jmx.rb').open('w') do |f|
			f.write <<'EOF'
data_processor('gc calls') do
end
EOF
		end
	end

	it 'should load from file and log that' do
		dpm = DataProcessorModules.new

		mod = nil
		out = Capture.stderr do
			mod = dpm.load_file(@modules_dir + 'system.rb')
		end

		mod.should be_a DataProcessorModule

		mod.data_processor_builders.should have(2).data_processor_builders
		mod.data_processor_builders.shift.should be_a DataProcessorBuilder
		mod.data_processor_builders.shift.should be_a DataProcessorBuilder

		out.should include("loading module 'system' from:")
		out.should include("loaded data processors for data types: CPU usage, memory usage")
	end

	it 'should log warning message if loaded file has no data processor definitions' do
		dpm = DataProcessorModules.new
		
		mod = nil
		out = Capture.stderr do
			mod = dpm.load_file(@modules_dir + 'empty.rb')
		end

		mod.should be_a DataProcessorModule
		mod.data_processor_builders.should have(0).data_processor_builders

		out.should include("WARN")
		out.should include("module 'empty' defines no data processors")
	end

	it 'should load directory in alphabetical order and log that' do
		dpm = DataProcessorModules.new
		
		modules = nil
		out = Capture.stderr do
			modules = dpm.load_directory(@modules_dir)
		end

		modules.should have(3).module

		modules.first.should be_a DataProcessorModule
		modules.first.name.should == 'empty'
		modules.shift.data_processor_builders.should have(0).data_processor_builders

		modules.first.should be_a DataProcessorModule
		modules.first.name.should == 'jmx'
		modules.shift.data_processor_builders.first.name.should == 'jmx/gc calls'

		modules.first.should be_a DataProcessorModule
		modules.first.name.should == 'system'
		modules.first.data_processor_builders.shift.name.should == 'system/memory usage'
		modules.shift.data_processor_builders.shift.name.should == 'system/CPU usage'

		out.should include("WARN")
		out.should include("loading module 'empty' from:")
		out.should include("module 'empty' defines no data processors")

		out.should include("loading module 'system' from:")
		out.should include("loaded data processors for data types: CPU usage, memory usage")

		out.should include("loading module 'jmx' from:")
		out.should include("loaded data processors for data types: gc calls")
	end

	it "should log error if module cannot be loaded" do
		module_file = Tempfile.new('bad_module')
		module_file.write 'raise "test error"'
		module_file.close

		dpm = DataProcessorModules.new
		
		out = Capture.stderr do
			dpm.load_file(module_file.path).should be_nil
		end

		out.should include("ERROR")
		out.should include("error while loading module 'bad_module")
		out.should include("test error")
	end

	after :all do
		@modules_dir.rmtree
	end
end

