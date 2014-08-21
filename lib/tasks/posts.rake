require 'lib/file_helper'
include FileHelper

desc "Create a new draft"
task :post do
  abort("rake aborted: 'no title provided'") unless ENV['title']
  create_draft(ENV['title'])
end

desc "Craete a Review Draft"
task :review do
  abort("rake aborted: 'no title provided'") unless ENV['title']
  create_draft ENV['title'], "review"
end

desc "Publish a post"
task :publish do
  abort("rake aborted: no filename provided") unless ENV['post']
  publish ENV['post']
end

desc "Unpublish a post"
task :unpublish do
  abort("rake aborted: no filename provided") unless ENV['post']
  unpublish ENV['post']
end