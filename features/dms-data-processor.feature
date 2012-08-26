Feature: Storage and processing of RawDataPoints to DataSets
	In order to produce DataSets
	Data processor has to strore RawDataPoints

	Background:
		Given data processor module directory system containing module system:
		"""
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
		"""
		Given dms-data-processor has debug enabled
		And dms-data-processor is using linger time of 4

	@test
	Scenario: Producing DataSets via REQ/REP query interface - all results
		Given dms-data-processor is using data processor modules directory system
		And dms-data-processor data bind address is ipc:///tmp/dms-data-processor-test-data
		And dms-data-processor query bind address is ipc:///tmp/dms-data-processor-test-query
		When dms-data-processor is running
		When I sent following RawDataPoints to ipc:///tmp/dms-data-processor-test-data:
			| location	| path						| component | timestamp | value | 
			| magi		| system/CPU usage/CPU/0	| user		|0			| 1		|
			| magi		| system/CPU usage/CPU/0	| user		|1			| 2		|
			| magi		| system/CPU usage/CPU/0	| system	|0			| 3		|
			| magi		| system/CPU usage/CPU/0	| system	|1			| 4		|
			| magi		| system/CPU usage/CPU/1	| user		|0			| 1		|
			| magi		| system/CPU usage/CPU/1	| user		|1			| 2		|
			| magi		| system/CPU usage/CPU/1	| system	|0			| 3		|
			| magi		| system/CPU usage/CPU/1	| system	|1			| 4		|
		And when I send following DataSetQueries to ipc:///tmp/dms-data-processor-test-query waiting for 2 DataSet:
			| tag_expression	| time_from	| time_span	| granularity	|
			| magi				| 1			| 1			| 1				|
		Then I should get following DataSets:
			| type_name | tag_set												| time_from | time_span	| components	| datum_count	|
			| CPU usage	| location:magi, module:system, system:CPU usage:CPU:0	| 1			| 1			| user, system	| 1, 1			|
			| CPU usage	| location:magi, module:system, system:CPU usage:CPU:1	| 1			| 1			| user, system	| 1, 1			|
		When dms-data-processor is terminated
		Then dms-data-processor log should include following entries:
			| Starting DMS Data Processor version |
			| DMS Data Processor ready |
			| DMS Data Processor done |

	@selective
	Scenario: Producing DataSets via REQ/REP query interface - selective result
		Given dms-data-processor is using data processor modules directory system
		And dms-data-processor data bind address is ipc:///tmp/dms-data-processor-test-data
		And dms-data-processor query bind address is ipc:///tmp/dms-data-processor-test-query
		When dms-data-processor is running
		When I sent following RawDataPoints to ipc:///tmp/dms-data-processor-test-data:
			| location	| path						| component | timestamp | value | 
			| magi		| system/CPU usage/CPU/0	| user		|0			| 1		|
			| magi		| system/CPU usage/CPU/0	| user		|1			| 2		|
			| magi		| system/CPU usage/CPU/0	| system	|0			| 3		|
			| magi		| system/CPU usage/CPU/0	| system	|1			| 4		|
			| magi		| system/CPU usage/CPU/1	| user		|0			| 1		|
			| magi		| system/CPU usage/CPU/1	| user		|1			| 2		|
			| magi		| system/CPU usage/CPU/1	| system	|0			| 3		|
			| magi		| system/CPU usage/CPU/1	| system	|1			| 4		|
		And I send following DataSetQueries to ipc:///tmp/dms-data-processor-test-query waiting for 1 DataSet:
			| tag_expression	| time_from	| time_span	| granularity	|
			| CPU:0				| 1			| 1			| 1				|
		Then I should get following DataSets:
			| type_name | tag_set												| time_from | time_span	| components	| datum_count	|
			| CPU usage	| location:magi, module:system, system:CPU usage:CPU:0	| 1			| 1			| user, system	| 1, 1			|

	@no_results
	Scenario: Producing DataSets via REQ/REP query interface - NoResults
		Given dms-data-processor is using data processor modules directory system
		And dms-data-processor data bind address is ipc:///tmp/dms-data-processor-test-data
		And dms-data-processor query bind address is ipc:///tmp/dms-data-processor-test-query
		When dms-data-processor is running
		When I sent following RawDataPoints to ipc:///tmp/dms-data-processor-test-data:
			| location	| path						| component | timestamp | value | 
			| magi		| system/CPU usage/CPU/0	| user		|0			| 1		|
			| magi		| system/CPU usage/CPU/0	| user		|1			| 2		|
			| magi		| system/CPU usage/CPU/0	| system	|0			| 3		|
			| magi		| system/CPU usage/CPU/0	| system	|1			| 4		|
			| magi		| system/CPU usage/CPU/1	| user		|0			| 1		|
			| magi		| system/CPU usage/CPU/1	| user		|1			| 2		|
			| magi		| system/CPU usage/CPU/1	| system	|0			| 3		|
			| magi		| system/CPU usage/CPU/1	| system	|1			| 4		|
		And I send following DataSetQueries to ipc:///tmp/dms-data-processor-test-query waiting for 1 DataSet:
			| tag_expression	| time_from	| time_span	| granularity	|
			| CPU:0				| 1			| 1			| 1				|
		When I send following DataSetQueries to ipc:///tmp/dms-data-processor-test-query waiting for 1 NoResults:
			| tag_expression	| time_from	| time_span	| granularity	|
			| bogous			| 1			| 1			| 1				|
		Then I should get NoResults response

	@discover
	Scenario: Responds for Discover messages
		Given dms-data-processor is using data processor modules directory system
		And dms-data-processor console connector subscribe address is ipc:///tmp/dms-console-connector-sub-test
		And dms-data-processor console connector publish address is ipc:///tmp/dms-console-connector-pub-test
		When I keep publishing Discover messages on test123 topic
		And dms-data-processor is running
		Then I should eventually get Hello response on test123 topic
		When I publish Discover messages as follows:
			| host_name | program				| topic |
			| /.*/		|						| good	|
			| abcd		| dms-data-processor	| bad	|
			|			| asdf					| bad	|
			| /abc/		|						| bad	|
			|			| dms-data-processor	| good	|
		Then I should get 2 Hello messages on good topic
		Then I should get 0 Hello messages on bad topic

	@pub_sub
	Scenario: Producing DataSets via PUB/SUB query interface
		Given dms-data-processor is using data processor modules directory system
		And dms-data-processor data bind address is ipc:///tmp/dms-data-processor-test-data
		And dms-data-processor console connector subscribe address is ipc:///tmp/dms-console-connector-sub-test
		And dms-data-processor console connector publish address is ipc:///tmp/dms-console-connector-pub-test
		When dms-data-processor is running
		When I sent following RawDataPoints to ipc:///tmp/dms-data-processor-test-data:
			| location	| path						| component | timestamp | value | 
			| magi		| system/CPU usage/CPU/0	| user		|0			| 1		|
			| magi		| system/CPU usage/CPU/0	| user		|1			| 2		|
			| magi		| system/CPU usage/CPU/0	| system	|0			| 3		|
			| magi		| system/CPU usage/CPU/0	| system	|1			| 4		|
			| magi		| system/CPU usage/CPU/1	| user		|0			| 1		|
			| magi		| system/CPU usage/CPU/1	| user		|1			| 2		|
			| magi		| system/CPU usage/CPU/1	| system	|0			| 3		|
			| magi		| system/CPU usage/CPU/1	| system	|1			| 4		|
		And I publish following DataSetQueries on test321 topic waiting for 2 DataSet:
			| tag_expression	| time_from	| time_span	| granularity	|
			| magi				| 1			| 1			| 1				|
		Then I should get following DataSets:
			| type_name | tag_set												| time_from | time_span	| components	| datum_count	|
			| CPU usage	| location:magi, module:system, system:CPU usage:CPU:0	| 1			| 1			| user, system	| 1, 1			|
			| CPU usage	| location:magi, module:system, system:CPU usage:CPU:1	| 1			| 1			| user, system	| 1, 1			|

