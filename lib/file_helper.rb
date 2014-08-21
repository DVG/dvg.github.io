require 'active_support/core_ext/string/inflections'
require 'fileutils'

class String
  def review?
    self == "review"
  end
end

module FileHelper
  CONFIG = {
    :drafts => "_drafts",
    :posts => "_posts"
  }
  
  def create_draft(title, type="post")
    filename = "#{title.parameterize}.md"
    puts "Creating a new #{type} #{filename} in _drafts"
    open("#{CONFIG[:drafts]}/#{filename}", "w") do |post|
      post.puts "---"
      post.puts "layout: #{type}"
      post.puts "title: #{title}"
      post.puts "thumb: up # Don't forget to mark down if it sucked" if type.review?
      post.puts "tldr: TODO: Enter a summary here" if type.review?
      post.puts "author: DVG"
      post.puts "comments: true"
      post.puts "---"
      post.puts "\n"
    end
  end

  def publish(post)
    abort("rake aborted: no draft named #{post}") unless File.exists? "#{CONFIG[:drafts]}/#{post}"
    puts "publishing #{post}"
    FileUtils.mv("#{CONFIG[:drafts]}/#{post}", "#{CONFIG[:posts]}/#{add_timestamp_to_post(post)}")
  end

  def unpublish(post)
    abort("rake aborted: no draft named #{post}") unless File.exists? "#{CONFIG[:posts]}/#{post}"
    puts "Unpublishing #{post}"
    FileUtils.mv("#{CONFIG[:posts]}/#{post}", "#{CONFIG[:drafts]}/#{remove_timestamp_from_post(post)}")
  end

private

  def add_timestamp_to_post(filename)
    timestamp = Time.now.strftime("%Y-%m-%d")
    "#{timestamp}-#{filename}"
  end

  def remove_timestamp_from_post(filename)
    filename.gsub(/\d{4}-\d{2}-\d{2}-/, "")
  end
end