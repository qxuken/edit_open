local M = {}

--- Extends tblA in place with content of a tblB. Assumes tables are array
--- @param tblA table
--- @param tblB table
--- @return table tblA
function M.tbl_extend(tblA, tblB)
	for _, value in ipairs(tblB) do
		table.insert(tblA, value)
	end
	return tblA
end

return M
