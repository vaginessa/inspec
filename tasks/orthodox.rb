# Documentation consistency and migration tasks for resources


namespace :orthodox do
  task main: [:since, :whinge, :extract]

  desc 'Examine each resource file and determine its version marker'
  task :since do
    puts Dir.pwd
    Dir.glob('docs/resources/*.md.erb') do |md_file|
      puts md_file
    end
  end

  desc 'Look for things to complain about in each resource doc file'
  task :whinge do
  end

  desc 'Search markdown files and emit YAML'
  task :extract do
  end
end
