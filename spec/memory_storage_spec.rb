require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe MemoryStorage do
	subject do
		MemoryStorage.new
	end

	it 'should store value under component path and location' do
		subject['magi', 'system/CPU usage/cpu/0', 'idle'] = 12345

		subject['system/CPU usage/cpu/0'].should == {
			'system/CPU usage/cpu/0' => {
				'magi' => {
					'idle' => 12345
				}
			}
		}
	end

	it 'should return nodes by path prefix' do
		subject['magi', 'system/CPU usage/cpu/0', 'idle'] = 12345
		subject['magi', 'system/CPU usage/cpu/0', 'usage'] = 213
		subject['magi', 'system/CPU usage/cpu/1', 'usage'] = 12
		subject['nina', 'system/CPU usage/cpu/1', 'usage'] = 89
		subject['nina', 'system/CPU usage/total', 'usage'] = 42

		subject['system/CPU usage/cpu'].should == {
			'system/CPU usage/cpu/0' => {
				'magi' => {
					'idle' => 12345,
					'usage' => 213
				}
			},
			'system/CPU usage/cpu/1' => {
				'magi' => {
					'usage' => 12
				},
				'nina' => {
					'usage' => 89
				}
			}
		}

		subject['system'].should == {
			'system/CPU usage/cpu/0' => {
				'magi' => {
					'idle' => 12345,
					'usage' => 213
				}
			},
			'system/CPU usage/cpu/1' => {
				'magi' => {
					'usage' => 12
				},
				'nina' => {
					'usage' => 89
				}
			},
			'system/CPU usage/total' => {
				'nina' => {
					'usage' => 42
				},
			}
		}
	end
end

