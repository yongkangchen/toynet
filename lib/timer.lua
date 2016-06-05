local tree = require "rbtree"()
local tree_insert = tree.insert
local tree_min = tree.min
local tree_remove = tree.remove

local timer = {}
local now = 0
function timer.add_timeout(sec, func)
	tree_insert(now + sec, func)
end

function timer.update(time_diff)
	now = now + time_diff
	while true do
		local node = tree_min()
		if not node then
			return -1
		end
		
		local diff = node.key - now 
		if diff > 0 then
			return diff
		end
		local func = node.data
		tree_remove(node)
		func()
	end
end
return timer