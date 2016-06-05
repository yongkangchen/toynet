local RB_BLACK = 0
local RB_RED = 1

local dummynode = {
	color = RB_BLACK
}

local function rbtree_node_init(node)
	node.parent = nil
	node.left = dummynode
	node.right = dummynode
end

local function rotate_left(self, node)
	local temp = node.right
	node.right = temp.left
	
	if temp.left ~= dummynode then
		temp.left.parent = node
	end

	temp.parent = node.parent
	if node == self.root then
		self.root = temp
	else
		local node_parent = node.parent
		if node == node_parent.left then
			node_parent.left = temp
		else
			node_parent.right = temp
		end
	end
	temp.left = node
	node.parent = temp
end

local function rotate_right(self, node)
	local temp = node.left
	node.left = temp.right

	if temp.right ~= dummynode then
		temp.right.parent = node
	end

	temp.parent = node.parent

	if node == self.root then
		self.root = temp
	else
		local node_parent = node.parent
		if node == node_parent.right then
			node_parent.right = temp
		else
			node_parent.left = temp
		end
	end
	temp.right = node
	node.parent = temp
end

local function rbtree_insert(self, node)
	rbtree_node_init(node)
	
	local current = self.root
	if current == dummynode then
		node.color = RB_BLACK
		self.root = node
		return
	end
	
	local key = node.key
	local p
	while true do
		if key < current.key then
			p = "left"
		else
			p = "right"
		end
		
		local pnode = current[p]
		if pnode == dummynode then
			break
		end
		current = pnode
	end

	current[p] = node
	node.parent = current
	node.color = RB_RED

	while node ~= self.root and node.parent.color == RB_RED do
		local node_parent = node.parent
		local node_grand = node_parent.parent
		if node_parent == node_grand.left then
			local temp = node_grand.right
			if temp.color == RB_RED then
				node_parent.color = RB_BLACK
				node_grand.color = RB_RED
				temp.color = RB_BLACK
				node = node_grand
			else
				if node == node_parent.right then
					node = node_parent
					rotate_left(self, node)
				end
				node_parent.color = RB_BLACK
				node_grand.color = RB_RED
				rotate_right(self, node_grand)
			end
		else
			local temp = node_grand.left
			if temp.color == RB_RED then
				node_parent.color = RB_BLACK
				node_grand.color = RB_RED
				temp.color = RB_BLACK
				node = node_grand
			else
				if node == node_parent.left then
					node = node_parent
					rotate_right(self, node)
				end
				node_parent.color = RB_BLACK
				node_grand.color = RB_RED
				rotate_left(self, node_grand)
			end
		end
	end
	self.root.color = RB_BLACK
end

local function get_min(node)
	while node.left ~= dummynode do
		node = node.left
	end
	return node
end

local function rbtree_remove(self, node)
	local temp, subst
	if node.left == dummynode then
		temp = node.right
		subst = node
	elseif node.right == dummynode then
		temp = node.left
		subst = node
	else
		subst = get_min(node.right)
		if subst.left ~= dummynode then
			temp = subst.left
		else
			temp = subst.right
		end
	end
	
	if subst == self.root then
		self.root = temp
		temp.color = RB_BLACK
		rbtree_node_init(node)
		return
	end
	
	local red = subst.color == RB_RED
	
	local subst_parent = subst.parent
	if subst == subst_parent.left then
		subst_parent.left = temp
	else
		subst_parent.right = temp
	end

	if subst == node then
		temp.parent = subst_parent
	else
		if subst_parent == node then
			temp.parent = subst
		else
			temp.parent = subst_parent
		end

		subst.left = node.left
		subst.right = node.right
		subst.parent = node.parent
		subst.color = node.color
		if node == self.root then
			self.root = subst
		else
			local node_parent = node.parent
			if node == node_parent.left then
				node_parent.left = subst
			else
				node_parent.right = subst
			end
		end

		if subst.left ~= dummynode then
			subst.left.parent = subst
		end
		
		if subst.right ~= dummynode then
			subst.right.parent = subst
		end
	end

	rbtree_node_init(node)
	if red then
		return
	end

	while temp ~= self.root and temp.color == RB_BLACK do
		if temp == temp.parent.left then
			local w = temp.parent.right
			if w.color == RB_RED then
				w.color = RB_BLACK
				temp.parent.color = RB_RED
				rotate_left(self, temp.parent)
				w = temp.parent.right
			end

			if w.left.color == RB_BLACK and w.right.color == RB_BLACK then
				w.color = RB_RED
				temp = temp.parent
			else
				if w.right.color == RB_BLACK then
					w.left.color = RB_BLACK
					w.color = RB_RED
					rotate_right(self, w)
					w = temp.parent.right
				end
				w.color = temp.parent.color
				temp.parent.color = RB_BLACK
				w.right.color = RB_BLACK
				rotate_left(self, temp.parent)
				temp = self.root
			end
		else
			local w = temp.parent.left
			if w.color == RB_RED then
				w.color = RB_BLACK
				temp.parent.color = RB_RED
				rotate_right(self, temp.parent)
				w = temp.parent.left
			end

			if w.left.color == RB_BLACK and w.right.color == RB_BLACK then
				w.color = RB_RED
				temp = temp.parent
			else
				if w.left.color == RB_BLACK then
					w.right.color = RB_BLACK
					w.color = RB_RED
					rotate_left(self, w)
					w = temp.parent.left
				end
				w.color = temp.parent.color
				temp.parent.color = RB_BLACK
				w.left.color = RB_BLACK
				rotate_right(self, temp.parent)
				temp = self.root
			end
		end
	end
	temp.color = RB_BLACK
end

return function()
	local rbtree = {
		root = dummynode,
	}
	function rbtree.insert(key, data)
		rbtree_insert(rbtree, {key = key, data = data})
	end
	
	function rbtree.remove(node)
		rbtree_remove(rbtree, node)
	end
	
	function rbtree.min()
		if rbtree.root == dummynode then 
			return
		end
		return get_min(rbtree.root)
	end
	return rbtree
end


