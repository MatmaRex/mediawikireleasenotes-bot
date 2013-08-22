# coding: utf-8
require 'rest-client'
require 'json'
require 'pp'

def API url
	data = RestClient.get(url)
	JSON.parse data.sub(/^\)\]\}'/, '')
end

if ARGV.empty?
	changes = API "https://gerrit.wikimedia.org/r/changes/?q=status:open+project:mediawiki/core&n=50000&o=CURRENT_REVISION&o=CURRENT_FILES&o=MESSAGES"
	borked = changes.select{|h|
		!h['mergeable'] &&
		# h['subject'] !~ /^merge branch|\b(wip|do not merge|don't merge)\b/i &&
		h['revisions'][ h['current_revision'] ]['files'].keys.grep(/^RELEASE-NOTES-/).length > 0 &&
		h['messages'].last['message'].match(/^rebase$|\bneeds? rebase\b|\b(doesn't|does not) merge\b|\bunable to be automatically merged\b/im)
	}

	puts borked.map{|h| [ h['_number'], h['subject'] ] }
	# exit
	
	borked.map!{|h| h['_number'] }
else
	borked = ARGV.to_a
end

puts "#{borked.length} changes."
# p borked; exit

borked.each do |chid|
	system *%W[git rebase --abort] # this can fail, it's okay
	okay = (
		system *%W[git reset --hard] and
		system *%W[git checkout master] and
		system *%W[git pull] and
		system *%W[git review -d #{chid}] and
		system *%W[git rebase master] and
		system *%W[git review -fy]
	)
	if okay
		puts "#{chid} rebased and submitted."
	else
		puts "#{chid} failed!"
	end
end

