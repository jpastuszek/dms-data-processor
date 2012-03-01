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

describe DataSetQueryController do
	let :data_processor_builder1 do
		Logging.logger.root.level = :fatal

		eval File.read(File.expand_path(File.dirname(__FILE__) + '/data_processor_builder_test1.rb'))
	end

	let :data_processor_builder2 do
		Logging.logger.root.level = :fatal

		eval File.read(File.expand_path(File.dirname(__FILE__) + '/data_processor_builder_test2.rb'))
	end

	let :storage_controller do
		st = StorageController.new(MemoryStorage.new(100))
		st << data_processor_builder1
		st << data_processor_builder2
		10.times do |sample|
			st.store(RawDataKey['nina', 'system/CPU usage/CPU/0', 'user'], RawDatum.new(Time.at(sample), sample * 1))
			st.store(RawDataKey['nina', 'system/CPU usage/CPU/0', 'system'], RawDatum.new(Time.at(sample), sample * 2))

			st.store(RawDataKey['magi', 'system/CPU usage/CPU/0', 'user'], RawDatum.new(Time.at(sample), sample * 1))
			st.store(RawDataKey['magi', 'system/CPU usage/CPU/0', 'system'], RawDatum.new(Time.at(sample), sample * 2))

			st.store(RawDataKey['magi', 'system/CPU usage/CPU/1', 'user'], RawDatum.new(Time.at(sample), sample * 2))
			st.store(RawDataKey['magi', 'system/CPU usage/CPU/1', 'system'], RawDatum.new(Time.at(sample), sample * 4))

			st.store(RawDataKey['nina', 'system/CPU usage/total', 'user'], RawDatum.new(Time.at(sample), sample * 4))
			st.store(RawDataKey['nina', 'system/CPU usage/total', 'system'], RawDatum.new(Time.at(sample), sample * 8))
		end
		st
	end

	subject do
		data_set_query_controller = DataSetQueryController.new(storage_controller)
	end

	describe '#query' do
		it 'should return array of DataSet objects matching tag expression and filled with time range of data' do
			data_sets = subject.query(DataSetQuery.new(1, 'magi', 6, 2, 1))
			data_sets.should have(3).data_sets

			data_set = data_sets.select{|ds| ds.tag_set.to_s == 'hello, location:magi, system:CPU count, world'}.shift
			data_set.type_name.should == 'count'
			data_set.component_data['count'].should have(1).dataum
			data_set.component_data['count'].first.last.should == 2

			data_set = data_sets.select{|ds| ds.tag_set.to_s == 'hello, location:magi, system:CPU usage:CPU:0, world'}.shift
			data_set.type_name.should == 'CPU usage'
			data_set.component_data['user'].should have(4).dataum
			data_set.component_data['system'].should have(4).dataum

			data_set = data_sets.select{|ds| ds.tag_set.to_s == 'hello, location:magi, system:CPU usage:CPU:1, world'}.shift
			data_set.type_name.should == 'CPU usage'
			data_set.component_data['user'].should have(4).dataum
			data_set.component_data['system'].should have(4).dataum
		end

		it 'should not return DataSet objects that time range does not match any data' do
			data_sets = subject.query(DataSetQuery.new(1, 'magi', 10, 20, 1))
			data_sets.should have(1).data_set

			data_set = data_sets.select{|ds| ds.tag_set.to_s == 'hello, location:magi, system:CPU count, world'}.shift
			data_set.type_name.should == 'count'
			data_set.component_data['count'].should have(1).dataum
			data_set.component_data['count'].first.last.should == 2
		end

		it 'should return empty array if there was no match' do
			data_sets = subject.query(DataSetQuery.new(1, 'bogous', 6, 2, 1))
			data_sets.should be_empty
		end
	end
end

