# encoding: utf-8
# copyright: 2018, The Authors

title 'sample section'

puts platform.family

describe "My platform: #{plat}" do
  it { should include 'plat' }
end

describe shadow do 
  its('count') { should be > 0 }
end

control 'Unchained shadow in a control' do
  describe shadow do 
    its('count') { should be > 0 }
  end    
end

control 'Chained shadow in a control' do
  # kaboom
  users = shadow.filter(password:/[^!|*]/).params.map { |x| x['user'] }
  describe shadow do 
    its('count') { should be > 0 }
  end    
end