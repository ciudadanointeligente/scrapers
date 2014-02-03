# coding: utf-8
require './sil_scrapable_classes'

if !(defined? Test::Unit::TestCase)
	CurrentHighChamberTable.new.process
	# CurrentLowChamberTable.new.process
end
