require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TagSpace do
	subject do
		TagSpace.new
	end

	it 'should store custom object under a tag and retrive it by tag pattern' do
		subject['System:memory'] = :hello_world

		subject['system'].should == [:hello_world]
		subject['Memory'].should == [:hello_world]
		subject['/sys/:/mem/'].should == [:hello_world]

		subject['java:memory'] = 42
		subject['Memory'].should include(:hello_world)
		subject['Memory'].should include(42)
		subject['java'].should == [42]

		subject['java:memory:heap:PermGenSpace'] = 'test'

		subject['java'].should include(42)
		subject['java'].should include('test')

		subject['/mem/'].should include(:hello_world)
		subject['/mem/'].should include('test')
		subject['/mem/'].should include(42)

		subject['/sys/:/mem/'].should include(:hello_world)
		subject['/sys/:/mem/'].should_not include('test')
		subject['/sys/:/mem/'].should_not include(42)

		subject['java:/mem/'].should_not include(:hello_world)
		subject['java:/mem/'].should include('test')
		subject['java:/mem/'].should include(42)

		subject['heap'].should_not include(:hello_world)
		subject['heap'].should include('test')
		subject['heap'].should_not include(42)

		subject['heap:java'].should be_empty
		subject['test'].should be_empty
		subject[''].should be_empty

		subject['java:memory:heap:EdenSpace'] = 'test2'

		subject['heap:/space/'].should_not include(:hello_world)
		subject['heap:/space/'].should include('test')
		subject['heap:/space/'].should include('test2')
		subject['heap:/space/'].should_not include(42)

		subject['//'].should include(:hello_world)
		subject['//'].should include('test')
		subject['//'].should include('test2')
		subject['//'].should include(42)
	end
end

