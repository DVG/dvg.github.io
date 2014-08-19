require 'active_support/core_ext/string/inflections'
require 'fileutils'

desc "Create a new draft"
task :post do
  abort("rake aborted: 'no title provided'") unless ENV['title']
  title = ENV['title']
  filename = "#{title.downcase.gsub(" ", "_").dasherize}.md"
  puts "Creating a new post #{filename} in _drafts"
  open("_drafts/#{filename}", "w") do |post|
    post.puts "---"
    post.puts "layout: post"
    post.puts "title: #{title}"
    post.puts "author: DVG"
    post.puts "comments: true"
    post.puts "---"
    post.puts "\n"
  end
end

desc "Publish a post"
task :publish do
  abort("rake aborted: no filename provided") unless ENV['post']
  filename = ENV['post']
  abort("rake aborted: no draft named #{filename}") unless File.exists? "_drafts/#{filename}"
  puts "publishing #{filename}"
  timestamp = Time.now.strftime("%Y-%m-%d")
  FileUtils.mv("_drafts/#{filename}", "_posts/#{timestamp}-#{filename}")
end

desc "Unpublish a post"
task :unpublish do
  abort("rake aborted: no filename provided") unless ENV['post']
  filename = ENV['post']
  abort("rake aborted: no draft named #{filename}") unless File.exists? "_posts/#{filename}"
  puts "Unpublishing #{filename}"
  new_filename = filename.gsub(/\d{4}-\d{2}-\d{2}-/, "")
  FileUtils.mv("_posts/#{filename}", "_drafts/#{new_filename}")
end